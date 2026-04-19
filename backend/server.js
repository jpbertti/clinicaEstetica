const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('./db');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET;

// Register Endpoint
app.post('/api/auth/register', async (req, res) => {
  const { nome, email, telefone, password } = req.body;

  if (!nome || !email || !password) {
    return res.status(400).json({ message: 'Nome, email e senha são obrigatórios' });
  }

  try {
    // Check if user already exists
    const [existing] = await db.query('SELECT id FROM usuarios WHERE email = ?', [email]);
    if (existing.length > 0) {
      return res.status(400).json({ message: 'Este e-mail já está em uso' });
    }

    // Hash the password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const [result] = await db.query(
      'INSERT INTO usuarios (nome, email, telefone, senha_hash) VALUES (?, ?, ?, ?)',
      [nome, email, telefone, hashedPassword]
    );
    const [newUser] = await db.query('SELECT criado_em FROM usuarios WHERE id = ?', [result.insertId]);
    
    res.status(201).json({
      message: 'Usuário criado com sucesso',
      usuario: {
        id: result.insertId,
        nome,
        email,
        telefone,
        criado_em: newUser[0].criado_em
      }
    });
  } catch (err) {
    console.error('ERRO NO REGISTRO:', err.message);
    res.status(500).json({ message: 'Erro ao criar usuário', details: err.message });
  }
});

// Login Endpoint
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Email e senha são obrigatórios' });
  }

  try {
    const [usuarios] = await db.query('SELECT * FROM usuarios WHERE email = ?', [email]);
    
    if (usuarios.length === 0) {
      return res.status(401).json({ message: 'Email ou senha incorretos' });
    }

    const usuario = usuarios[0];

    // Verificar senha criptografada
    const isMatch = await bcrypt.compare(password, usuario.senha_hash);

    if (!isMatch) {
      return res.status(401).json({ message: 'Email ou senha incorretos' });
    }

    console.log('LOGIN SUCESSO:', { nome: usuario.nome, email: usuario.email, telefone: usuario.telefone });

    const token = jwt.sign(
      { id: usuario.id, email: usuario.email, funcao: usuario.funcao },
      JWT_SECRET,
      { expiresIn: '8h' }
    );

    res.json({
      token,
      usuario: {
        id: usuario.id,
        nome: usuario.nome,
        email: usuario.email,
        telefone: usuario.telefone,
        funcao: usuario.funcao,
        criado_em: usuario.criado_em
      }
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Erro no servidor' });
  }
});

// Update Profile Endpoint (Editar E-mail e Telefone)
app.put('/api/auth/update-profile', async (req, res) => {
  const { id, email, telefone } = req.body;

  if (!id) {
    return res.status(400).json({ message: 'ID do usuário é obrigatório' });
  }

  try {
    const updates = [];
    const params = [];

    if (email) {
      if (!email.includes('@') || !email.includes('.')) {
        return res.status(400).json({ message: 'Email inválido. Deve conter @ e um domínio (ex: .com, .br)' });
      }
      updates.push('email = ?');
      params.push(email);
    }

    if (telefone) {
      // Remover tudo que não for dígito
      const phoneDigits = telefone.replace(/\D/g, '');
      if (phoneDigits.length !== 11) {
        return res.status(400).json({ message: 'Telefone inválido. Deve ter exatamente 11 dígitos (DDD + número)' });
      }
      updates.push('telefone = ?');
      params.push(telefone);
    }

    if (updates.length === 0) {
      return res.status(400).json({ message: 'Nenhum campo para atualizar' });
    }

    params.push(id);
    const sql = `UPDATE usuarios SET ${updates.join(', ')} WHERE id = ?`;
    await db.query(sql, params);

    res.json({ message: 'Perfil atualizado com sucesso!' });
  } catch (err) {
    console.error('ERRO NA ATUALIZAÇÃO:', err.message);
    res.status(500).json({ message: 'Erro ao atualizar perfil', details: err.message });
  }
});

// Hello endpoint
app.get('/', (req, res) => {
  res.send('Backend Clínica Estética rodando com sucesso!');
});

app.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
