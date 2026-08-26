-- ============================================================================
-- Plataforma SECAMI — Schema inicial unificado (treino + academia)
-- Ref: SPEC-Plataforma-SECAMI.md §8
-- PostgreSQL 18+ (usa uuidv7() nativo). snake_case, timestamptz, soft-delete.
-- ============================================================================

-- Função utilitária: mantém updated_at em dia em updates diretos por SQL.
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 1. IDENTIDADE E ORGANIZAÇÃO
-- ============================================================================

CREATE TABLE app_user (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  ldap_guid         uuid UNIQUE,
  sam_account_name  text UNIQUE,
  email             text,
  nome              text NOT NULL,
  tipo_identidade   text NOT NULL DEFAULT 'ad'
                      CHECK (tipo_identidade IN ('ad','local')),
  ativo             boolean NOT NULL DEFAULT true,
  legacy_id         text UNIQUE,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_app_user_upd BEFORE UPDATE ON app_user
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE user_role (
  user_id  uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  role     text NOT NULL
             CHECK (role IN ('admin','gerente','recepcao','professor','aluno')),
  PRIMARY KEY (user_id, role)
);

CREATE TABLE organizacao (
  id            uuid PRIMARY KEY DEFAULT uuidv7(),
  nome          text NOT NULL,
  dono_user_id  uuid NOT NULL REFERENCES app_user(id),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE membro_org (
  id       uuid PRIMARY KEY DEFAULT uuidv7(),
  org_id   uuid NOT NULL REFERENCES organizacao(id) ON DELETE CASCADE,
  user_id  uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  papel    text NOT NULL DEFAULT 'professor' CHECK (papel IN ('professor','admin')),
  status   text NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','pendente')),
  UNIQUE (org_id, user_id)
);

-- ============================================================================
-- 2. CADASTRO BÁSICO
-- ============================================================================

CREATE TABLE department (
  id          uuid PRIMARY KEY DEFAULT uuidv7(),
  name        text NOT NULL,
  sigla       text,
  andar       text,
  active      boolean NOT NULL DEFAULT true,
  legacy_id   text UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_department_upd BEFORE UPDATE ON department
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE media (
  id            uuid PRIMARY KEY DEFAULT uuidv7(),
  tipo          text NOT NULL CHECK (tipo IN ('foto_aluno','exercicio')),
  storage_key   text NOT NULL,
  content_type  text,
  origem_url     text,           -- URL de origem (ex.: base44) p/ migração de mídia
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE student (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id          uuid REFERENCES app_user(id) ON DELETE SET NULL,
  full_name        text NOT NULL,
  cpf              text UNIQUE,                    -- só dígitos, normalizado
  matricula        text,
  student_type     text NOT NULL DEFAULT 'Civil'
                     CHECK (student_type IN ('Civil','Militar')),
  department_id    uuid REFERENCES department(id) ON DELETE SET NULL,
  phone            text,
  email            text,
  birth_date       date,
  weight_kg        numeric(6,2),
  height_cm        numeric(6,2),
  goal             text,
  photo_id         uuid REFERENCES media(id) ON DELETE SET NULL,
  atestado_numero  text,
  atestado_data    date,
  active           boolean NOT NULL DEFAULT true,
  legacy_id        text UNIQUE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz
);
CREATE INDEX idx_student_cpf ON student(cpf);
CREATE INDEX idx_student_name ON student(lower(full_name));
CREATE INDEX idx_student_dept ON student(department_id);
CREATE TRIGGER trg_student_upd BEFORE UPDATE ON student
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 3. AGENDAMENTO E PRESENÇA
-- ============================================================================

CREATE TABLE slot_config (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  slot_start        text NOT NULL,          -- "HH:MM"
  slot_end          text NOT NULL,
  max_capacity      integer NOT NULL DEFAULT 40,
  civil_restricted  boolean NOT NULL DEFAULT false,
  blocked           boolean NOT NULL DEFAULT false,
  block_reason      text,
  legacy_id         text UNIQUE,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (slot_start)
);
CREATE TRIGGER trg_slot_config_upd BEFORE UPDATE ON slot_config
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE blocked_date (
  id          uuid PRIMARY KEY DEFAULT uuidv7(),
  date        date NOT NULL,
  slot_start  text,                          -- NULL = dia inteiro
  reason      text,
  legacy_id   text UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_blocked_date_date ON blocked_date(date);

CREATE TABLE appointment (
  id           uuid PRIMARY KEY DEFAULT uuidv7(),
  student_id   uuid NOT NULL REFERENCES student(id) ON DELETE CASCADE,
  date         date NOT NULL,
  slot_start   text NOT NULL,
  slot_end     text NOT NULL,
  status       text NOT NULL DEFAULT 'agendado'
                 CHECK (status IN ('agendado','confirmado','cancelado','faltou')),
  forced       boolean NOT NULL DEFAULT false,
  notes        text,
  created_by   uuid REFERENCES app_user(id) ON DELETE SET NULL,
  legacy_id    text UNIQUE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz
);
CREATE INDEX idx_appointment_date ON appointment(date);
CREATE INDEX idx_appointment_student ON appointment(student_id);
CREATE INDEX idx_appointment_date_slot ON appointment(date, slot_start);
-- Impede duplicidade de agendamento ativo no mesmo dia+slot (regra §9.4).
CREATE UNIQUE INDEX uq_appointment_ativo
  ON appointment(student_id, date, slot_start)
  WHERE status <> 'cancelado' AND deleted_at IS NULL;

CREATE TABLE check_in (
  id              uuid PRIMARY KEY DEFAULT uuidv7(),
  student_id      uuid NOT NULL REFERENCES student(id) ON DELETE CASCADE,
  appointment_id  uuid REFERENCES appointment(id) ON DELETE SET NULL,
  date            date NOT NULL,
  check_in_time   text NOT NULL,             -- "HH:MM"
  check_out_time  text,
  notes           text,
  created_by      uuid REFERENCES app_user(id) ON DELETE SET NULL,
  legacy_id       text UNIQUE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_checkin_date ON check_in(date);
CREATE INDEX idx_checkin_student ON check_in(student_id);
CREATE TRIGGER trg_checkin_upd BEFORE UPDATE ON check_in
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE frequencia (
  id          uuid PRIMARY KEY DEFAULT uuidv7(),
  student_id  uuid NOT NULL REFERENCES student(id) ON DELETE CASCADE,
  data_hora   timestamptz NOT NULL,
  tipo        text NOT NULL CHECK (tipo IN ('entrada','saida')),
  origem      text NOT NULL DEFAULT 'catraca' CHECK (origem IN ('catraca','manual')),
  legacy_id   text UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_frequencia_student ON frequencia(student_id);
CREATE INDEX idx_frequencia_data ON frequencia(data_hora);

-- ============================================================================
-- 4. CATÁLOGO E PRESCRIÇÃO DE TREINO (visão academia)
-- ============================================================================

CREATE TABLE exercise (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  name              text NOT NULL,
  muscle_group      text,
  description       text,
  equipment         text,
  padrao_movimento  text,
  video_url         text,
  photo_id          uuid REFERENCES media(id) ON DELETE SET NULL,
  escopo            text NOT NULL DEFAULT 'global' CHECK (escopo IN ('global','custom')),
  owner_user_id     uuid REFERENCES app_user(id) ON DELETE SET NULL,
  arquivado         boolean NOT NULL DEFAULT false,
  legacy_id         text UNIQUE,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_exercise_group ON exercise(muscle_group);
CREATE INDEX idx_exercise_name ON exercise(lower(name));
CREATE TRIGGER trg_exercise_upd BEFORE UPDATE ON exercise
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE workout_plan (
  id            uuid PRIMARY KEY DEFAULT uuidv7(),
  student_id    uuid NOT NULL REFERENCES student(id) ON DELETE CASCADE,
  professor_id  uuid REFERENCES app_user(id) ON DELETE SET NULL,
  sheet_label   text NOT NULL DEFAULT 'A' CHECK (sheet_label IN ('A','B','C','D')),
  title         text NOT NULL,
  active        boolean NOT NULL DEFAULT true,
  valid_until   date,
  legacy_id     text UNIQUE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);
CREATE INDEX idx_workout_plan_student ON workout_plan(student_id);
CREATE TRIGGER trg_workout_plan_upd BEFORE UPDATE ON workout_plan
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE workout_plan_exercise (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  workout_plan_id  uuid NOT NULL REFERENCES workout_plan(id) ON DELETE CASCADE,
  exercise_id      uuid REFERENCES exercise(id) ON DELETE SET NULL,
  exercise_name    text,                       -- fallback quando exercise_id não resolvido
  ordem            integer NOT NULL DEFAULT 0,
  sets             integer,
  reps             text,
  rest_seconds     integer,
  notes            text
);
CREATE INDEX idx_wpe_plan ON workout_plan_exercise(workout_plan_id);

CREATE TABLE workout_log (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  student_id       uuid NOT NULL REFERENCES student(id) ON DELETE CASCADE,
  workout_plan_id  uuid REFERENCES workout_plan(id) ON DELETE SET NULL,
  sheet_label      text,
  date             date NOT NULL,
  completed        boolean NOT NULL DEFAULT false,
  legacy_id        text UNIQUE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_workout_log_student ON workout_log(student_id);
CREATE TRIGGER trg_workout_log_upd BEFORE UPDATE ON workout_log
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE workout_log_exercise (
  id              uuid PRIMARY KEY DEFAULT uuidv7(),
  workout_log_id  uuid NOT NULL REFERENCES workout_log(id) ON DELETE CASCADE,
  exercise_name   text NOT NULL,
  load            text,
  completed       boolean NOT NULL DEFAULT true
);
CREATE INDEX idx_wle_log ON workout_log_exercise(workout_log_id);

-- ============================================================================
-- 5. TREINO AVANÇADO (domínio reps — offline-first, colunas de sync)
-- ============================================================================

CREATE TABLE routine (
  id               uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id          uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  nome             text NOT NULL,
  tipo             text NOT NULL DEFAULT 'fixo',
  dias_da_semana   jsonb NOT NULL DEFAULT '[]',
  ordem            integer NOT NULL DEFAULT 0,
  ativo            boolean NOT NULL DEFAULT true,
  origem           text NOT NULL DEFAULT 'propria' CHECK (origem IN ('propria','atribuida')),
  atribuido_por    uuid REFERENCES app_user(id) ON DELETE SET NULL,
  device_id        text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz
);
CREATE INDEX idx_routine_user ON routine(user_id);
CREATE INDEX idx_routine_updated ON routine(updated_at);

CREATE TABLE routine_exercise (
  id                uuid PRIMARY KEY DEFAULT uuidv7(),
  routine_id        uuid NOT NULL REFERENCES routine(id) ON DELETE CASCADE,
  exercise_id       text NOT NULL,             -- pode ser "seed:<slug>" ou uuid
  ordem             integer NOT NULL DEFAULT 0,
  series_planejadas jsonb NOT NULL DEFAULT '[]',
  notas             text,
  grupo_id          text,
  grupo_tipo        text NOT NULL DEFAULT 'normal' CHECK (grupo_tipo IN ('normal','bi_set','circuito')),
  rounds            integer,
  device_id         text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz
);
CREATE INDEX idx_routine_exercise_routine ON routine_exercise(routine_id);
CREATE INDEX idx_routine_exercise_updated ON routine_exercise(updated_at);

CREATE TABLE workout_session (
  id                      uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id                 uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  routine_id              uuid REFERENCES routine(id) ON DELETE SET NULL,
  iniciado_em             timestamptz NOT NULL DEFAULT now(),
  finalizado_em           timestamptz,
  duracao_total_segundos  integer,
  notas                   text,
  sentimento              integer,
  device_id               text,
  updated_at              timestamptz NOT NULL DEFAULT now(),
  deleted_at              timestamptz
);
CREATE INDEX idx_session_user ON workout_session(user_id);
CREATE INDEX idx_session_updated ON workout_session(updated_at);

CREATE TABLE set_log (
  id                          uuid PRIMARY KEY DEFAULT uuidv7(),
  session_id                  uuid NOT NULL REFERENCES workout_session(id) ON DELETE CASCADE,
  exercise_id                 text NOT NULL,
  ordem_no_treino             integer NOT NULL,
  numero_serie                integer NOT NULL,
  reps_realizadas             integer,
  carga_kg                    numeric(7,2),
  duracao_segundos            integer,
  rpe                         integer,
  tipo_serie                  text NOT NULL DEFAULT 'normal',
  executada                   boolean NOT NULL DEFAULT true,
  motivo_pulo                 text,
  substituido_de_exercise_id  text,
  device_id                   text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now(),
  deleted_at                  timestamptz
);
CREATE INDEX idx_set_log_session ON set_log(session_id);
CREATE INDEX idx_set_log_updated ON set_log(updated_at);

CREATE TABLE cardio_session (
  id              uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id         uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  modalidade      text NOT NULL,
  duracao_minutos integer NOT NULL,
  distancia_km    numeric(7,2),
  intensidade     integer,
  fc_media        integer,
  fc_max          integer,
  calorias        integer,
  external_source text,
  external_id     text,
  synced_at       timestamptz,
  executado_em    timestamptz NOT NULL DEFAULT now(),
  device_id       text,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);
CREATE INDEX idx_cardio_user ON cardio_session(user_id);
CREATE INDEX idx_cardio_updated ON cardio_session(updated_at);

CREATE TABLE recommender_run (
  id             uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id        uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  versao_regras  text NOT NULL,
  perfil_json    jsonb NOT NULL,
  triagem_json   jsonb,                        -- dado sensível: só com consentimento
  treino_json    jsonb NOT NULL,
  divisao        text,
  bloqueado      boolean NOT NULL DEFAULT false,
  sincronizavel  boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_recommender_user ON recommender_run(user_id);

-- ============================================================================
-- 6. COACHING (professor ↔ aluno ↔ academia)
-- ============================================================================

CREATE TABLE vinculo (
  id            uuid PRIMARY KEY DEFAULT uuidv7(),
  professor_id  uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  aluno_id      uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','pendente','encerrado')),
  aceito_em     timestamptz,
  org_id        uuid REFERENCES organizacao(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);
CREATE INDEX idx_vinculo_professor ON vinculo(professor_id);
CREATE INDEX idx_vinculo_aluno ON vinculo(aluno_id);
CREATE UNIQUE INDEX uq_vinculo_ativo ON vinculo(professor_id, aluno_id)
  WHERE deleted_at IS NULL;
CREATE TRIGGER trg_vinculo_upd BEFORE UPDATE ON vinculo
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE convite (
  id          uuid PRIMARY KEY DEFAULT uuidv7(),
  codigo      text NOT NULL UNIQUE,
  tipo        text NOT NULL DEFAULT 'professor_aluno'
                CHECK (tipo IN ('professor_aluno','org_professor')),
  criado_por  uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  org_id      uuid REFERENCES organizacao(id) ON DELETE SET NULL,
  usos_max    integer NOT NULL DEFAULT 1,
  usos        integer NOT NULL DEFAULT 0,
  expira_em   timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_convite_codigo ON convite(codigo);

-- ============================================================================
-- 7. COMUNICAÇÃO E AUDITORIA
-- ============================================================================

CREATE TABLE notice (
  id            uuid PRIMARY KEY DEFAULT uuidv7(),
  title         text NOT NULL,
  content       text NOT NULL,
  type          text NOT NULL DEFAULT 'info' CHECK (type IN ('info','warning','success')),
  active        boolean NOT NULL DEFAULT true,
  target_roles  jsonb NOT NULL DEFAULT '["aluno"]',
  created_by    uuid REFERENCES app_user(id) ON DELETE SET NULL,
  legacy_id     text UNIQUE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_notice_upd BEFORE UPDATE ON notice
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE audit_log (
  id             uuid PRIMARY KEY DEFAULT uuidv7(),
  actor_user_id  uuid REFERENCES app_user(id) ON DELETE SET NULL,
  acao           text NOT NULL,
  entidade       text NOT NULL,
  entidade_id    uuid,
  payload        jsonb,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_actor ON audit_log(actor_user_id);
CREATE INDEX idx_audit_created ON audit_log(created_at);
