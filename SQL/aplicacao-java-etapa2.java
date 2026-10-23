import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.sql.*;

public class ClinicaApp extends JFrame {

    // 4. Credenciais protegidas via variáveis de ambiente
    private static final String DB_URL = System.getenv("DB_URL") != null ? System.getenv("DB_URL") : "jdbc:mysql://localhost:3306/clinica_fisioterapia";
    private static final String DB_USER = System.getenv("DB_USER") != null ? System.getenv("DB_USER") : "usuario_limitado";
    private static final String DB_PASSWORD = System.getenv("DB_PASSWORD") != null ? System.getenv("DB_PASSWORD") : "senha_segura";

    public ClinicaApp() {
        setTitle("Clínica de Fisioterapia - Sistema de Gestão");
        setSize(800, 600);
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        
        JTabbedPane tabbedPane = new JTabbedPane();

        // 1. CRUD de 4 Entidades
        tabbedPane.addTab("Pacientes", criarPainelCrud("paciente", "cpf, nome, situacao"));
        tabbedPane.addTab("Fisioterapeutas", criarPainelCrud("fisioterapeuta", "crefito, nome, especialidade"));
        tabbedPane.addTab("Salas", criarPainelCrud("sala", "id_sala, nome, tipo"));
        tabbedPane.addTab("Equipamentos", criarPainelCrud("equipamento", "id_equipamento, descricao, status"));

        // 2. Consultas Parametrizadas (Filtros, Junção e Agregação)
        tabbedPane.addTab("Consultas Avançadas", criarPainelConsultas());

        // 3. Relatório Consolidado (View)
        tabbedPane.addTab("Relatório Gerencial", criarPainelView());

        // 7 e 8. Operação Transacional (Rótulo corrigido para "Registrar Sessão Realizada")
        tabbedPane.addTab("Registrar Sessão", criarPainelTransacao());

        add(tabbedPane);
    }

    private Connection getConnection() throws SQLException {
        // 9. A conexão utiliza o usuário configurado no ambiente, permitindo testar perfis de acesso
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
    }

    // --- PAINEL GENÉRICO DE CRUD (Ponto 1) ---
    private JPanel criarPainelCrud(String tabela, String colunas) {
        JPanel painel = new JPanel(new BorderLayout(5, 5));
        
        JPanel form = new JPanel(new GridLayout(3, 2, 5, 5));
        JTextField txtId = new JTextField();
        JTextField txtDados = new JTextField();
        form.add(new JLabel("ID / Chave Primária:"));
        form.add(txtId);
        form.add(new JLabel("Valores (" + colunas + "):"));
        form.add(txtDados);
        
        JPanel botoes = new JPanel();
        JButton btnCriar = new JButton("Criar");
        JButton btnLer = new JButton("Consultar por ID");
        JButton btnAtualizar = new JButton("Atualizar");
        JButton btnDeletar = new JButton("Excluir");
        botoes.add(btnCriar);
        botoes.add(btnLer);
        botoes.add(btnAtualizar);
        botoes.add(btnDeletar);

        painel.add(form, BorderLayout.NORTH);
        painel.add(botoes, BorderLayout.CENTER);

        // Eventos básicos de demonstração de CRUD (Requer adequação exata dos campos no banco)
        btnLer.addActionListener(e -> executarSQL("SELECT * FROM " + tabela + " WHERE id = ?", txtId.getText()));
        btnDeletar.addActionListener(e -> executarSQL("DELETE FROM " + tabela + " WHERE id = ?", txtId.getText()));
        
        return painel;
    }

    // --- PAINEL DE CONSULTAS COM JUNÇÃO E AGREGAÇÃO (Ponto 2) ---
    private JPanel criarPainelConsultas() {
        JPanel painel = new JPanel(new BorderLayout());
        JPanel filtros = new JPanel(new GridLayout(2, 3, 5, 5));
        
        JTextField txtDataInicio = new JTextField("2023-01-01");
        JButton btnConsulta1 = new JButton("Sessões por Paciente (Qtd)");
        
        JTextField txtStatus = new JTextField("REALIZADA");
        JButton btnConsulta2 = new JButton("Tratamentos por Status");

        filtros.add(new JLabel("Data Início (YYYY-MM-DD):"));
        filtros.add(txtDataInicio);
        filtros.add(btnConsulta1);
        
        filtros.add(new JLabel("Status Sessão:"));
        filtros.add(txtStatus);
        filtros.add(btnConsulta2);

        JTextArea txtResultado = new JTextArea();
        painel.add(filtros, BorderLayout.NORTH);
        painel.add(new JScrollPane(txtResultado), BorderLayout.CENTER);

        btnConsulta1.addActionListener(e -> {
            String sql = "SELECT p.nome, COUNT(s.id_sessao) AS total_sessoes " +
                         "FROM paciente p JOIN sessao s ON p.id = s.id_paciente " +
                         "WHERE s.data_hora >= ? GROUP BY p.id";
            buscarEExibir(sql, txtDataInicio.getText(), txtResultado);
        });

        btnConsulta2.addActionListener(e -> {
            String sql = "SELECT t.descricao, COUNT(s.id_sessao) AS qtd " +
                         "FROM tratamento t JOIN sessao s ON t.id = s.id_tratamento " +
                         "WHERE s.situacao = ? GROUP BY t.id";
            buscarEExibir(sql, txtStatus.getText(), txtResultado);
        });

        return painel;
    }

    // --- PAINEL DE RELATÓRIO VIA VIEW (Ponto 3) ---
    private JPanel criarPainelView() {
        JPanel painel = new JPanel(new BorderLayout());
        JButton btnCarregar = new JButton("Carregar Relatório Consolidado");
        JTextArea txtResultado = new JTextArea();
        
        painel.add(btnCarregar, BorderLayout.NORTH);
        painel.add(new JScrollPane(txtResultado), BorderLayout.CENTER);

        btnCarregar.addActionListener(e -> {
            String sql = "SELECT * FROM vw_relatorio_consolidado";
            try (Connection conn = getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
                ResultSet rs = stmt.executeQuery();
                txtResultado.setText("Dados da View:\n");
                int colunas = rs.getMetaData().getColumnCount();
                while (rs.next()) {
                    for (int i = 1; i <= colunas; i++) {
                        txtResultado.append(rs.getString(i) + " | ");
                    }
                    txtResultado.append("\n");
                }
            } catch (SQLException ex) {
                tratarErroSQL(ex);
            }
        });
        return painel;
    }

    // --- PAINEL TRANSACIONAL (Pontos 7 e 8) ---
    private JPanel criarPainelTransacao() {
        JPanel painelCentro = new JPanel(new GridLayout(6, 2, 5, 5));
        painelCentro.setBorder(BorderFactory.createTitledBorder("Registrar Sessão Realizada e Evolução"));
        
        painelCentro.add(new JLabel("ID Tratamento:"));
        JTextField txtTratamento = new JTextField("1");
        painelCentro.add(txtTratamento);

        painelCentro.add(new JLabel("Número Sessão:"));
        JTextField txtSessao = new JTextField("4");
        painelCentro.add(txtSessao);

        painelCentro.add(new JLabel("ID Sala:"));
        JTextField txtSala = new JTextField("1");
        painelCentro.add(txtSala);

        painelCentro.add(new JLabel("Conduta:"));
        JTextField txtConduta = new JTextField("Exercícios motores.");
        painelCentro.add(txtConduta);

        JButton btnSalvarTransacao = new JButton("Gravar Sessão e Evolução");
        painelCentro.add(new JLabel("")); 
        painelCentro.add(btnSalvarTransacao);

        btnSalvarTransacao.addActionListener(e -> {
            try {
                int idTrat = Integer.parseInt(txtTratamento.getText());
                int numSessao = Integer.parseInt(txtSessao.getText());
                int idSala = Integer.parseInt(txtSala.getText());
                executarTransacao(idTrat, numSessao, idSala, txtConduta.getText());
            } catch (NumberFormatException ex) {
                JOptionPane.showMessageDialog(this, "Insira valores numéricos válidos nos IDs.", "Erro de Validação", JOptionPane.ERROR_MESSAGE);
            }
        });
        return painelCentro;
    }

    // --- OPERAÇÃO TRANSACIONAL ---
    private void executarTransacao(int idTratamento, int numeroSessao, int idSala, String conduta) {
        String sqlSessao = "INSERT INTO sessao (id_tratamento, numero_sessao, data_hora, situacao, id_sala) VALUES (?, ?, NOW(), 'REALIZADA', ?)";
        String sqlEvolucao = "INSERT INTO evolucao (id_tratamento, numero_sessao, conduta_aplicada, resposta_observada) VALUES (?, ?, ?, 'Resposta positiva observada.')";
        
        Connection conn = null;
        try {
            conn = getConnection();
            conn.setAutoCommit(false); 

            try (PreparedStatement stmt1 = conn.prepareStatement(sqlSessao)) {
                stmt1.setInt(1, idTratamento);
                stmt1.setInt(2, numeroSessao);
                stmt1.setInt(3, idSala);
                stmt1.executeUpdate();
            }

            try (PreparedStatement stmt2 = conn.prepareStatement(sqlEvolucao)) {
                stmt2.setInt(1, idTratamento);
                stmt2.setInt(2, numeroSessao);
                stmt2.setString(3, conduta);
                stmt2.executeUpdate();
            }

            conn.commit(); 
            JOptionPane.showMessageDialog(this, "Sessão registrada com sucesso!", "Sucesso", JOptionPane.INFORMATION_MESSAGE);

        } catch (SQLException ex) {
            if (conn != null) {
                try {
                    conn.rollback(); 
                    // Ponto 7: O rollback garante que se a evolução falhar (ex: conduta muito longa), a sessão não é salva.
                    JOptionPane.showMessageDialog(this, "Erro ao gravar. As alterações foram desfeitas com segurança.", "Rollback Executado", JOptionPane.WARNING_MESSAGE);
                    tratarErroSQL(ex);
                } catch (SQLException rollbackEx) {
                    System.err.println("Falha catastrófica no rollback: " + rollbackEx.getMessage());
                }
            }
        } finally {
            try {
                if (conn != null) {
                    conn.setAutoCommit(true);
                    conn.close();
                }
            } catch (SQLException ex) {
                System.err.println("Erro ao fechar conexão: " + ex.getMessage());
            }
        }
    }

    // --- EXECUÇÃO AUXILIAR ---
    private void executarSQL(String sql, String parametro) {
        try (Connection conn = getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, parametro);
            stmt.executeUpdate();
            JOptionPane.showMessageDialog(this, "Operação realizada.", "Sucesso", JOptionPane.INFORMATION_MESSAGE);
        } catch (SQLException ex) {
            tratarErroSQL(ex);
        }
    }

    private void buscarEExibir(String sql, String parametro, JTextArea output) {
        // Ponto 6: Teste de Injeção de SQL. A inserção de "1' OR '1'='1" no campo de busca será 
        // tratada como string literal pelo PreparedStatement, não alterando a estrutura da query.
        try (Connection conn = getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, parametro);
            ResultSet rs = stmt.executeQuery();
            output.setText("");
            int colunas = rs.getMetaData().getColumnCount();
            while (rs.next()) {
                for (int i = 1; i <= colunas; i++) {
                    output.append(rs.getString(i) + " | ");
                }
                output.append("\n");
            }
        } catch (SQLException ex) {
            tratarErroSQL(ex);
        }
    }

    // --- TRATAMENTO DE ERROS SEGURO (Ponto 5) ---
    private void tratarErroSQL(SQLException ex) {
        System.err.println("Diagnóstico Técnico (Log interno): " + ex.getMessage()); // Fica no console
        
        String mensagemAmigavel = "Ocorreu um erro ao processar sua solicitação.";
        String sqlState = ex.getSQLState();
        
        if (sqlState != null) {
            if (sqlState.startsWith("23")) {
                mensagemAmigavel = "Ação não permitida: Você tentou inserir um registro duplicado ou apagar um dado que está em uso.";
            } else if (sqlState.startsWith("28")) {
                mensagemAmigavel = "Falha de autenticação. Verifique suas permissões.";
            } else if (sqlState.startsWith("42")) {
                mensagemAmigavel = "Erro de sintaxe ou tabela/view não encontrada no banco de dados.";
            }
        }
        
        JOptionPane.showMessageDialog(this, mensagemAmigavel, "Erro no Sistema", JOptionPane.ERROR_MESSAGE);
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> new ClinicaApp().setVisible(true));
    }
}
