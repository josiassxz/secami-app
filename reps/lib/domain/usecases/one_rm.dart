/// Estimativa de 1RM pela formula de Epley: `carga * (1 + reps / 30)`.
///
/// Recebe a carga em kg (mesma unidade de armazenamento dos set_logs) e o numero
/// de repeticoes. Retorna a carga estimada para 1 repeticao, na mesma unidade da
/// entrada. Para reps <= 0 retorna a propria carga (Epley em 1 rep = carga).
double oneRmEpley(double cargaKg, double reps) {
  if (reps <= 0) return cargaKg;
  return cargaKg * (1 + reps / 30.0);
}
