const db = require('./db');

async function fixDatabase() {
  try {
    console.log('Verificando tabela de usuários...');
    
    // Tenta adicionar a coluna. Se já existir, o MySQL retornará um erro que ignoraremos.
    await db.query(`
      ALTER TABLE usuarios 
      ADD COLUMN telefone VARCHAR(20) AFTER email;
    `);
    
    console.log('✅ Coluna "telefone" adicionada com sucesso!');
    process.exit(0);
  } catch (err) {
    if (err.code === 'ER_DUP_COLUMN_NAME') {
      console.log('ℹ️ A coluna "telefone" já existe.');
      process.exit(0);
    } else {
      console.error('❌ Erro ao atualizar banco de dados:', err.message);
      process.exit(1);
    }
  }
}

fixDatabase();
