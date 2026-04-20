class StringUtils {
  static final List<String> _conjunctions = [
    'de', 'do', 'da', 'dos', 'das',
    'em', 'no', 'na', 'nos', 'nas',
    'por', 'pelo', 'pela', 'pelos', 'pelas',
    'para', 'com', 'sem', 'sob', 'sobre',
    'a', 'o', 'e', 'ou', 'mas', 'que',
    'este', 'esta', 'isto', 'esse', 'essa', 'isso', 'aquele', 'aquela', 'aquilo'
  ];

  /// Converte uma string para Title Case, capitalizando a primeira letra de cada palavra,
  /// exceto para preposições e conjunções comuns (ligação).
  static String toTitleCase(String text) {
    if (text.isEmpty) return text;

    final words = text.toLowerCase().split(' ');
    final capitalizedWords = <String>[];

    for (var i = 0; i < words.length; i++) {
        final word = words[i];
        if (word.isEmpty) continue;

        // Sempre capitaliza a primeira palavra ou se não for uma conjunção
        if (i == 0 || !_conjunctions.contains(word)) {
            capitalizedWords.add(word[0].toUpperCase() + word.substring(1));
        } else {
            capitalizedWords.add(word);
        }
    }

    return capitalizedWords.join(' ');
  }
}
