# Script para corrigir tipografia nas telas Flutter
# Adiciona google_fonts import e fontFamily nos TextStyle que não têm fontFamily

$libPath = "lib"

# Arquivos a excluir (já têm configuração própria ou não são telas)
$excludeFiles = @("main.dart", "pdf_service.dart", "app_colors.dart")

$dartFiles = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | 
    Where-Object { 
        $name = $_.Name
        -not ($excludeFiles | Where-Object { $name -eq $_ })
    }

$fixedFiles = 0

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # Verificar se o arquivo tem TextStyle( mas não tem google_fonts import
    $hasTextStyle = $content -match 'TextStyle\('
    if (-not $hasTextStyle) { continue }
    
    # Adicionar import do google_fonts se não existir
    $hasGoogleFontsImport = $content -match "import 'package:google_fonts/google_fonts.dart'"
    if (-not $hasGoogleFontsImport) {
        # Adicionar após o primeiro import
        $content = $content -replace "(import 'package:flutter/material\.dart';)", "`$1`r`nimport 'package:google_fonts/google_fonts.dart';"
    }
    
    # Padrão para encontrar TextStyle( sem fontFamily
    # Substitui TextStyle( por TextStyle(fontFamily: 'Manrope', 
    # para TextStyle que NÃO já têm fontFamily especificado
    
    # Usando regex para encontrar blocos TextStyle que não têm fontFamily
    # Esta abordagem substitui de forma simples e segura
    
    # Substituição 1: TextStyle( sem fontFamily -> adiciona fontFamily: 'Manrope'
    # Usar lookahead negativo para garantir que não já tem fontFamily
    
    # Nota: Esta substituição é baseada em linha por linha para evitar problemas de multiline
    $lines = $content -split "`r?`n"
    $newLines = @()
    $i = 0
    $modified = $false
    
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        
        # Verificar se esta linha tem TextStyle( e coletar o bloco
        if ($line -match 'TextStyle\(') {
            # Verificar se já tem fontFamily na mesma linha
            if ($line -match 'fontFamily') {
                $newLines += $line
                $i++
                continue
            }
            
            # Coletar o bloco TextStyle completo (pode ser multi-linha)
            $block = $line
            $j = $i + 1
            $depth = ($line.Split('(').Count - $line.Split(')').Count)
            
            while ($depth -gt 0 -and $j -lt $lines.Count) {
                $block += "`n" + $lines[$j]
                $depth += ($lines[$j].Split('(').Count - $lines[$j].Split(')').Count)
                $j++
            }
            
            # Verificar se o bloco tem fontFamily
            if ($block -match 'fontFamily') {
                # Já tem fontFamily, não modificar
                $newLines += ($block -split "`n")
                $i = $j
                continue
            }
            
            # Determinar qual fonte usar baseado no fontSize
            $fontFamily = 'Manrope'
            if ($block -match 'fontSize:\s*(\d+(?:\.\d+)?)') {
                $fontSize = [double]$Matches[1]
                if ($fontSize -ge 20) {
                    $fontFamily = 'Playfair Display'
                }
            }
            
            # Adicionar fontFamily após TextStyle(
            $modifiedBlock = $block -replace 'TextStyle\(', "TextStyle(fontFamily: '$fontFamily', "
            
            # Dividir novamente e adicionar às linhas
            $newLines += ($modifiedBlock -split "`n")
            $i = $j
            $modified = $true
        } else {
            $newLines += $line
            $i++
        }
    }
    
    if ($modified) {
        $newContent = $newLines -join "`r`n"
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
        Write-Host "✅ Corrigido: $($file.Name)"
        $fixedFiles++
    }
}

Write-Host ""
Write-Host "✅ Total de arquivos corrigidos: $fixedFiles de $($dartFiles.Count) arquivos processados"
