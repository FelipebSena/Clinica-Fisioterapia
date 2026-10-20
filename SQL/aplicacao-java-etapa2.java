import javax.swing.*;
import java.awt.*;
import java.sql.*;

public class ClinicaApp extends JFrame {

    // Configurações da base de dados
    private static final String DB_URL = "jdbc:mysql://localhost:3306/clinica_fisioterapia";
    private static final String DB_USER = "root";
    private static final String DB_PASSWORD = "root"; // Altera para a tua senha

    public ClinicaApp() {
        setTitle("Clínica de Fisioterapia - Etapa 2");
        setSize(500, 300);
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setLayout(new BorderLayout(10, 10));

        // Painel Superior: Consulta de Paciente (B2 - Consulta Parametrizada)
        JPanel painelTop = new JPanel(new FlowLayout());
        painelTop.add(new JLabel("Pesquisar Paciente (CPF):"));
        JTextField txtCpf = new JTextField(15);
        JButton btnBuscar = new JButton("Buscar");
        painelTop.add(txtCpf);
        painelTop.add(btnBuscar);

        // Painel Central: Operação Transacional (B3 - Sessão + Evolução)
        JPanel painelCentro = new JPanel(new GridLayout(5, 2, 5, 5));
        painelCentro.setBorder(BorderFactory.createTitledBorder("Transação: Agendar Sessão e Evolução"));
        
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

        JButton btnSalvarTransacao = new JButton("Executar Transação");
        painelCentro.add(new JLabel("")); // Espaçador
        painelCentro.add(btnSalvarTransacao);

        add(painelTop, BorderLayout.NORTH);
        add(painelCentro, BorderLayout.CENTER);

        // Ação do Botão Buscar Paciente
        btnBuscar.addActionListener(e -> buscarPaciente(txtCpf.getText()));

        // Ação do Botão Executar Transação
        btnSalvarTransacao.addActionListener(e -> {
            try {
                int idTrat = Integer.parseInt(txtTratamento.getText());
                int numSessao = Integer.parseInt(txtSessao.getText());
                int idSala = Integer.parseInt(txtSala.getText());
                String conduta = txtConduta.getText();
                executarTransacao(idTrat, numSessao, idSala, conduta);
            } catch (NumberFormatException ex) {
                JOptionPane.showMessageDialog(this, "Por favor, insere valores numéricos válidos nos IDs.", "Erro de Validação", JOptionPane.ERROR_MESSAGE);
            }
        });
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
    }

    // Método para ler dados (Evita SQL Injection)
    private void buscarPaciente(String cpf) {
        String sql = "SELECT nome, situacao FROM paciente WHERE cpf = ?";
        try (Connection conn = getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, cpf);
            ResultSet rs = stmt.executeQuery();
            if (rs.next()) {
                JOptionPane.showMessageDialog(this, "Paciente: " + rs.getString("nome") + "\nSituação: " + rs.getString("situacao"), "Resultado", JOptionPane.INFORMATION_MESSAGE);
            } else {
                JOptionPane.showMessageDialog(this, "Paciente não encontrado.", "Aviso", JOptionPane.WARNING_MESSAGE);
            }
        } catch (SQLException ex) {
            JOptionPane.showMessageDialog(this, "Erro na base de dados: " + ex.getMessage(), "Erro", JOptionPane.ERROR_MESSAGE);
        }
    }

    // Método transacional (Sessão + Evolução)
    private void executarTransacao(int idTratamento, int numeroSessao, int idSala, String conduta) {
        String sqlSessao = "INSERT INTO sessao (id_tratamento, numero_sessao, data_hora, situacao, id_sala) VALUES (?, ?, NOW(), 'REALIZADA', ?)";
        String sqlEvolucao = "INSERT INTO evolucao (id_tratamento, numero_sessao, conduta_aplicada, resposta_observada) VALUES (?, ?, ?, 'Resposta positiva observada.')";
        
        Connection conn = null;
        try {
            conn = getConnection();
            conn.setAutoCommit(false); // Inicia transação manual

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

            conn.commit(); // Confirma as duas operações
            JOptionPane.showMessageDialog(this, "Transação Multitabela concluída com sucesso!", "Sucesso", JOptionPane.INFORMATION_MESSAGE);

        } catch (SQLException ex) {
            if (conn != null) {
                try {
                    conn.rollback(); // Desfaz tudo em caso de erro (ex: violação de PK)
                    JOptionPane.showMessageDialog(this, "Operação desfeita (Rollback). Erro: " + ex.getMessage(), "Erro de Integridade", JOptionPane.ERROR_MESSAGE);
                } catch (SQLException rollbackEx) {
                    rollbackEx.printStackTrace();
                }
            }
        } finally {
            try {
                if (conn != null) {
                    conn.setAutoCommit(true);
                    conn.close();
                }
            } catch (SQLException ex) {
                ex.printStackTrace();
            }
        }
    }

    public static void main(String[] args) {
        // Inicia a aplicação na Thread correta do Swing
        SwingUtilities.invokeLater(() -> {
            new ClinicaApp().setVisible(true);
        });
    }
}