import javax.swing.*;
import java.awt.*;
import java.sql.*;

public class ClinicaApp extends JFrame {

    // Credenciais diretas para a sua máquina
    private static final String DB_URL = "jdbc:mysql://localhost:3306/clinica_fisioterapia";
    private static final String DB_USER = "root";
    private static final String DB_PASSWORD = "Mysql@1998";

    public ClinicaApp() {
        setTitle("Clínica de Fisioterapia - Sistema de Gestão");
        setSize(800, 600);
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

        JTabbedPane tabbedPane = new JTabbedPane();

        // 1. CRUD (Ajustado para os campos obrigatórios da base de dados)
        tabbedPane.addTab("Pacientes", criarPainelCrud("paciente", "cpf, nome, data_nascimento"));
        tabbedPane.addTab("Salas", criarPainelCrud("sala", "codigo, capacidade"));

        // 2. Consultas Parametrizadas
        tabbedPane.addTab("Consultas Avançadas", criarPainelConsultas());

        // 3. Relatório Consolidado (View)
        tabbedPane.addTab("Relatório Gerencial", criarPainelView());

        // 4. Operação Transacional (Rollback)
        tabbedPane.addTab("Registrar Sessão", criarPainelTransacao());

        add(tabbedPane);
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
    }

    // --- PAINEL GENÉRICO DE CRUD COM AÇÕES FUNCIONAIS ---
    private JPanel criarPainelCrud(String tabela, String colunas) {
        JPanel painel = new JPanel(new BorderLayout(5, 5));

        JPanel form = new JPanel(new GridLayout(3, 2, 5, 5));
        JTextField txtId = new JTextField();
        JTextField txtDados = new JTextField();
        form.add(new JLabel("ID da Tabela (apenas para Consultar/Excluir):"));
        form.add(txtId);
        form.add(new JLabel("Valores para Criar (" + colunas + "):"));
        form.add(txtDados);

        JPanel botoes = new JPanel();
        JButton btnCriar = new JButton("Criar");
        JButton btnLer = new JButton("Consultar por ID");
        JButton btnDeletar = new JButton("Excluir");
        botoes.add(btnCriar);
        botoes.add(btnLer);
        botoes.add(btnDeletar);

        painel.add(form, BorderLayout.NORTH);
        painel.add(botoes, BorderLayout.CENTER);

        // --- AÇÃO: CRIAR (INSERT) ---
        btnCriar.addActionListener(e -> {
            String[] colArray = colunas.split(",");
            String[] valArray = txtDados.getText().split(",");

            if (valArray.length != colArray.length) {
                JOptionPane.showMessageDialog(this, "Preencha exatamente " + colArray.length + " valores separados por vírgula.\nExemplo: 07428282128, Caio Tobias, 1998-02-23", "Aviso de Validação", JOptionPane.WARNING_MESSAGE);
                return;
            }

            StringBuilder placeholders = new StringBuilder();
            for (int i = 0; i < colArray.length; i++) {
                placeholders.append("?");
                if (i < colArray.length - 1) placeholders.append(", ");
            }

            String sql = "INSERT INTO " + tabela + " (" + colunas + ") VALUES (" + placeholders.toString() + ")";
            try (Connection conn = getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
                for (int i = 0; i < valArray.length; i++) {
                    stmt.setString(i + 1, valArray[i].trim());
                }
                stmt.executeUpdate();
                JOptionPane.showMessageDialog(this, "Registo criado com sucesso na tabela " + tabela + "!", "Sucesso", JOptionPane.INFORMATION_MESSAGE);
            } catch (SQLException ex) {
                tratarErroSQL(ex);
            }
        });

        // --- AÇÃO: CONSULTAR (SELECT) ---
        btnLer.addActionListener(e -> {
            String pkName = "id_" + tabela; // O padrão da sua base de dados é id_paciente, id_sala, etc.
            String sql = "SELECT * FROM " + tabela + " WHERE " + pkName + " = ?";
            try (Connection conn = getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setString(1, txtId.getText().trim());
                ResultSet rs = stmt.executeQuery(); // CORRIGIDO: Usa executeQuery para SELECT
                if (rs.next()) {
                    StringBuilder sb = new StringBuilder();
                    int count = rs.getMetaData().getColumnCount();
                    for (int i = 1; i <= count; i++) {
                        sb.append(rs.getMetaData().getColumnName(i)).append(": ").append(rs.getString(i)).append("\n");
                    }
                    JOptionPane.showMessageDialog(this, sb.toString(), "Dados Encontrados", JOptionPane.INFORMATION_MESSAGE);
                } else {
                    JOptionPane.showMessageDialog(this, "Nenhum registo encontrado com o ID fornecido.", "Aviso", JOptionPane.WARNING_MESSAGE);
                }
            } catch (SQLException ex) {
                tratarErroSQL(ex);
            }
        });

        // --- AÇÃO: EXCLUIR (DELETE) ---
        btnDeletar.addActionListener(e -> {
            String pkName = "id_" + tabela;
            String sql = "DELETE FROM " + tabela + " WHERE " + pkName + " = ?";
            try (Connection conn = getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setString(1, txtId.getText().trim());
                int rows = stmt.executeUpdate();
                if (rows > 0) {
                    JOptionPane.showMessageDialog(this, "Registo eliminado com sucesso!", "Sucesso", JOptionPane.INFORMATION_MESSAGE);
                } else {
                    JOptionPane.showMessageDialog(this, "Nenhum registo encontrado para eliminar.", "Aviso", JOptionPane.WARNING_MESSAGE);
                }
            } catch (SQLException ex) {
                tratarErroSQL(ex);
            }
        });

        return painel;
    }

    // --- PAINEL DE CONSULTAS AVANÇADAS ---
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
                    "FROM paciente p JOIN sessao s ON p.id_paciente = s.id_tratamento " +
                    "WHERE s.data_hora >= ? GROUP BY p.id_paciente";
            buscarEExibir(sql, txtDataInicio.getText(), txtResultado);
        });

        btnConsulta2.addActionListener(e -> {
            String sql = "SELECT t.descricao_condicao, COUNT(s.id_sessao) AS qtd " +
                    "FROM tratamento t JOIN sessao s ON t.id_tratamento = s.id_tratamento " +
                    "WHERE s.situacao = ? GROUP BY t.id_tratamento";
            buscarEExibir(sql, txtStatus.getText(), txtResultado);
        });

        return painel;
    }

    // --- PAINEL DE RELATÓRIO VIA VIEW ---
    private JPanel criarPainelView() {
        JPanel painel = new JPanel(new BorderLayout());
        JButton btnCarregar = new JButton("Carregar Relatório Consolidado");
        JTextArea txtResultado = new JTextArea();

        painel.add(btnCarregar, BorderLayout.NORTH);
        painel.add(new JScrollPane(txtResultado), BorderLayout.CENTER);

        btnCarregar.addActionListener(e -> {
            String sql = "SELECT * FROM vw_paciente_restrito"; // Ajustado para a view que existe na sua base
            try (Connection conn = getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
                ResultSet rs = stmt.executeQuery();
                txtResultado.setText("Dados da View (vw_paciente_restrito):\n");
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

    // --- PAINEL TRANSACIONAL ---
    private JPanel criarPainelTransacao() {
        JPanel painelCentro = new JPanel(new GridLayout(6, 2, 5, 5));
        painelCentro.setBorder(BorderFactory.createTitledBorder("Registrar Sessão Realizada e Evolução"));

        painelCentro.add(new JLabel("ID Tratamento:"));
        JTextField txtTratamento = new JTextField("1");
        painelCentro.add(txtTratamento);

        painelCentro.add(new JLabel("Número Sessão:"));
        JTextField txtSessao = new JTextField("99");
        painelCentro.add(txtSessao);

        painelCentro.add(new JLabel("ID Sala (9999 p/ forçar erro):"));
        JTextField txtSala = new JTextField("9999");
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

    // --- OPERAÇÃO TRANSACIONAL COM ROLLBACK ---
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
            JOptionPane.showMessageDialog(this, "Sessão e Evolução registradas com sucesso!", "Sucesso", JOptionPane.INFORMATION_MESSAGE);

        } catch (SQLException ex) {
            if (conn != null) {
                try {
                    conn.rollback();
                    JOptionPane.showMessageDialog(this, "Erro ao gravar. As alterações foram desfeitas com segurança (Rollback).", "Rollback Executado", JOptionPane.WARNING_MESSAGE);
                } catch (SQLException rollbackEx) {
                    System.err.println("Falha no rollback: " + rollbackEx.getMessage());
                }
            } else {
                JOptionPane.showMessageDialog(this, "Falha de conexão com a base de dados.", "Erro de Conexão", JOptionPane.ERROR_MESSAGE);
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

    private void buscarEExibir(String sql, String parametro, JTextArea output) {
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

    private void tratarErroSQL(SQLException ex) {
        System.err.println("Diagnóstico Técnico: " + ex.getMessage());
        String mensagemAmigavel = "Ocorreu um erro ao processar a sua solicitação:\n" + ex.getMessage();
        JOptionPane.showMessageDialog(this, mensagemAmigavel, "Erro na Base de Dados", JOptionPane.ERROR_MESSAGE);
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> new ClinicaApp().setVisible(true));
    }
}
