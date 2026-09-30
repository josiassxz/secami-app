package br.gov.goias.secami.academy.appointment;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.common.Cpf;
import jakarta.servlet.ServletOutputStream;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Gera arquivo Excel (.xlsx) com os dados filtrados do relatório de frequência.
 */
@Service
public class RelatorioExportService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    private final SchedulingService scheduling;

    public RelatorioExportService(SchedulingService scheduling) {
        this.scheduling = scheduling;
    }

    public void exportar(LocalDate from, LocalDate to, String status, String q, ServletOutputStream out) throws IOException {
        // Busca todos os registros filtrados (sem paginação para exportação completa)
        var page = scheduling.byRangeFiltered(from, to, status, q,
                org.springframework.data.domain.PageRequest.of(0, 100_000));
        List<Appointment> rows = page.getContent();

        try (Workbook wb = new XSSFWorkbook()) {
            Sheet sheet = wb.createSheet("Relatório");

            // Header style
            CellStyle headerStyle = wb.createCellStyle();
            Font headerFont = wb.createFont();
            headerFont.setBold(true);
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            // Headers
            String[] headers = {"Data", "Aluno", "CPF", "Tipo", "Horário Início", "Horário Fim",
                    "Status", "Entrada Real", "Saída Real", "Permanência (min)"};
            Row headerRow = sheet.createRow(0);
            for (int i = 0; i < headers.length; i++) {
                Cell cell = headerRow.createCell(i);
                cell.setCellValue(headers[i]);
                cell.setCellStyle(headerStyle);
            }

            // Data rows
            int rowNum = 1;
            for (Appointment a : rows) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(a.getDate() != null ? a.getDate().format(DATE_FMT) : "");
                row.createCell(1).setCellValue(a.getStudent() != null ? a.getStudent().getFullName() : "");
                row.createCell(2).setCellValue(a.getStudent() != null ? Cpf.format(a.getStudent().getCpf()) : "");
                row.createCell(3).setCellValue(a.getStudent() != null ? a.getStudent().getStudentType() : "");
                row.createCell(4).setCellValue(a.getSlotStart() != null ? a.getSlotStart() : "");
                row.createCell(5).setCellValue(a.getSlotEnd() != null ? a.getSlotEnd() : "");
                row.createCell(6).setCellValue(a.getStatus() != null ? a.getStatus() : "");
                row.createCell(7).setCellValue(a.getEntradaConfirmadaEm() != null
                        ? a.getEntradaConfirmadaEm().toLocalTime().format(TIME_FMT) : "");
                row.createCell(8).setCellValue(a.getSaidaConfirmadaEm() != null
                        ? a.getSaidaConfirmadaEm().toLocalTime().format(TIME_FMT) : "");

                // Permanência em minutos
                if (a.getEntradaConfirmadaEm() != null && a.getSaidaConfirmadaEm() != null) {
                    long mins = java.time.Duration.between(a.getEntradaConfirmadaEm(), a.getSaidaConfirmadaEm()).toMinutes();
                    row.createCell(9).setCellValue(Math.max(0, mins));
                } else {
                    row.createCell(9).setCellValue("");
                }
            }

            // Auto-size columns
            for (int i = 0; i < headers.length; i++) {
                sheet.autoSizeColumn(i);
            }

            // Segunda aba: Permanência média por usuário
            Sheet perUserSheet = wb.createSheet("Permanência por Usuário");
            String[] perUserHeaders = {"Aluno", "CPF", "Tipo", "Total Registros", "Permanência Média (min)"};
            Row perUserHeaderRow = perUserSheet.createRow(0);
            for (int i = 0; i < perUserHeaders.length; i++) {
                Cell cell = perUserHeaderRow.createCell(i);
                cell.setCellValue(perUserHeaders[i]);
                cell.setCellStyle(headerStyle);
            }

            // Agrupa permanência por aluno
            java.util.Map<java.util.UUID, double[]> userStats = new java.util.LinkedHashMap<>();
            java.util.Map<java.util.UUID, Student> userMap = new java.util.HashMap<>();
            for (Appointment a : rows) {
                if (a.getStudent() == null) continue;
                java.util.UUID uid = a.getStudent().getId();
                userMap.put(uid, a.getStudent());
                double[] stats = userStats.computeIfAbsent(uid, k -> new double[]{0, 0});
                stats[0]++; // count
                if (a.getEntradaConfirmadaEm() != null && a.getSaidaConfirmadaEm() != null) {
                    long mins = java.time.Duration.between(a.getEntradaConfirmadaEm(), a.getSaidaConfirmadaEm()).toMinutes();
                    if (mins >= 0) stats[1] += mins;
                }
            }

            int perUserRow = 1;
            for (var entry : userStats.entrySet()) {
                Student s = userMap.get(entry.getKey());
                double[] stats = entry.getValue();
                Row row = perUserSheet.createRow(perUserRow++);
                row.createCell(0).setCellValue(s != null ? s.getFullName() : "");
                row.createCell(1).setCellValue(s != null ? Cpf.format(s.getCpf()) : "");
                row.createCell(2).setCellValue(s != null ? s.getStudentType() : "");
                row.createCell(3).setCellValue((long) stats[0]);
                double media = stats[0] > 0 ? stats[1] / stats[0] : 0;
                row.createCell(4).setCellValue(Math.round(media * 10.0) / 10.0);
            }

            for (int i = 0; i < perUserHeaders.length; i++) {
                perUserSheet.autoSizeColumn(i);
            }

            wb.write(out);
        }
    }
}