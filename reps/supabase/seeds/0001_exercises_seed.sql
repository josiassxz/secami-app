-- Auto-gerado por tool/seed_exercises.dart
-- Insere 100 exercicios na biblioteca global.
-- Idempotente: usa upsert por slug.

begin;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'supino_reto_barra',
  'Supino reto com barra',
  'Empurrada horizontal classica, foco em peito medio.',
  'supino_reto_barra',
  'peito',
  ARRAY['triceps','ombros']::grupo_muscular[],
  'empurrada_horizontal',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'supino_inclinado_barra',
  'Supino inclinado com barra',
  'Inclinacao de 30 a 45 graus, foco em peito superior.',
  'supino_inclinado_barra',
  'peito',
  ARRAY['ombros','triceps']::grupo_muscular[],
  'empurrada_horizontal',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'supino_declinado_barra',
  'Supino declinado com barra',
  'Declinio de 15 a 30 graus, foco em peito inferior.',
  'supino_declinado_barra',
  'peito',
  ARRAY['triceps']::grupo_muscular[],
  'empurrada_horizontal',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'supino_reto_halter',
  'Supino reto com halteres',
  'Amplitude maior que a barra, melhor para simetria.',
  'supino_reto_halter',
  'peito',
  ARRAY['triceps','ombros']::grupo_muscular[],
  'empurrada_horizontal',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'supino_inclinado_halter',
  'Supino inclinado com halteres',
  'Peito superior com amplitude e estabilizacao maior.',
  'supino_inclinado_halter',
  'peito',
  ARRAY['ombros','triceps']::grupo_muscular[],
  'empurrada_horizontal',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'crucifixo_halter',
  'Crucifixo com halteres',
  'Isolador de peito com bracos semiflexionados.',
  'crucifixo_halter',
  'peito',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'crucifixo_cabo_cross',
  'Crucifixo na polia (cross-over)',
  'Tensao continua, otimo finalizador de peito.',
  'crucifixo_cabo_cross',
  'peito',
  '{}',
  'isolador',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'supino_maquina',
  'Supino na maquina',
  'Tragetoria fixa, ideal para iniciar ou finalizar.',
  'supino_maquina',
  'peito',
  ARRAY['triceps']::grupo_muscular[],
  'empurrada_horizontal',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'voador_peitoral',
  'Voador (peck deck)',
  'Isolador horizontal de peito em maquina.',
  'voador_peitoral',
  'peito',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'flexao_solo',
  'Flexao de braco',
  'Peso corporal, peito e triceps com core ativado.',
  'flexao_solo',
  'peito',
  ARRAY['triceps','core']::grupo_muscular[],
  'empurrada_horizontal',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'flexao_inclinada',
  'Flexao inclinada',
  'Mais facil que a flexao solo, pes elevados invertem.',
  'flexao_inclinada',
  'peito',
  ARRAY['triceps']::grupo_muscular[],
  'empurrada_horizontal',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'paralelas_peito',
  'Paralelas (mergulho) com foco em peito',
  'Inclinacao do tronco a frente direciona o estimulo.',
  'paralelas_peito',
  'peito',
  ARRAY['triceps']::grupo_muscular[],
  'empurrada_vertical',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'puxada_frente_pegada_pronada',
  'Puxada na frente pegada pronada',
  'Largura aberta. Latissimo e redondo maior.',
  'puxada_frente_pegada_pronada',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_vertical',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'puxada_frente_pegada_neutra',
  'Puxada na frente pegada neutra',
  'Palmas se enfrentam, menos estresse no ombro.',
  'puxada_frente_pegada_neutra',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_vertical',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'puxada_frente_pegada_supinada',
  'Puxada na frente pegada supinada',
  'Recrutamento maior de biceps e latissimo.',
  'puxada_frente_pegada_supinada',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_vertical',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'remada_baixa_cabo',
  'Remada baixa no cabo',
  'Puxada horizontal sentada com tensao continua.',
  'remada_baixa_cabo',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_horizontal',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'remada_curvada_barra',
  'Remada curvada com barra',
  'Tronco a 45 graus, dorsal e meio das costas.',
  'remada_curvada_barra',
  'costas',
  ARRAY['biceps','posterior']::grupo_muscular[],
  'puxada_horizontal',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'remada_curvada_halter',
  'Remada curvada com halteres',
  'Pegada neutra com amplitude maior.',
  'remada_curvada_halter',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_horizontal',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'remada_cavalinho',
  'Remada cavalinho (T-bar)',
  'Carga pesada em angulo, espessura das costas.',
  'remada_cavalinho',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_horizontal',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'remada_serrote',
  'Remada serrote (unilateral halter)',
  'Apoio no banco, amplitude maxima em um lado.',
  'remada_serrote',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_horizontal',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'remada_maquina',
  'Remada na maquina',
  'Tragetoria fixa, ideal para alta carga com seguranca.',
  'remada_maquina',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_horizontal',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'barra_fixa_pronada',
  'Barra fixa pegada pronada',
  'Peso corporal classico de puxada vertical.',
  'barra_fixa_pronada',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_vertical',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'barra_fixa_supinada',
  'Barra fixa pegada supinada (chin-up)',
  'Mais biceps que a versao pronada.',
  'barra_fixa_supinada',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_vertical',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'pulldown_estreito',
  'Pulldown pegada estreita',
  'Puxada vertical com triangulo, foco em parte baixa.',
  'pulldown_estreito',
  'costas',
  ARRAY['biceps']::grupo_muscular[],
  'puxada_vertical',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'levantamento_terra_convencional',
  'Levantamento terra convencional',
  'Composto pesado, posterior e ergueras espinhais.',
  'levantamento_terra_convencional',
  'posterior',
  ARRAY['costas','gluteos','core']::grupo_muscular[],
  'dobradica_quadril',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'pullover_halter',
  'Pullover com halter',
  'Alongamento de latissimo e expansao toracica.',
  'pullover_halter',
  'costas',
  ARRAY['peito']::grupo_muscular[],
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'desenvolvimento_militar_barra',
  'Desenvolvimento militar com barra',
  'Empurrada vertical pesada, ombros e triceps.',
  'desenvolvimento_militar_barra',
  'ombros',
  ARRAY['triceps','core']::grupo_muscular[],
  'empurrada_vertical',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'desenvolvimento_halter',
  'Desenvolvimento com halteres',
  'Sentado ou em pe, amplitude maior que a barra.',
  'desenvolvimento_halter',
  'ombros',
  ARRAY['triceps']::grupo_muscular[],
  'empurrada_vertical',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'elevacao_lateral_halter',
  'Elevacao lateral com halteres',
  'Isolador classico de deltoide medio.',
  'elevacao_lateral_halter',
  'ombros',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'elevacao_lateral_cabo',
  'Elevacao lateral no cabo',
  'Tensao continua no deltoide medio.',
  'elevacao_lateral_cabo',
  'ombros',
  '{}',
  'isolador',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'elevacao_frontal_halter',
  'Elevacao frontal com halteres',
  'Deltoide anterior em isolamento.',
  'elevacao_frontal_halter',
  'ombros',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'elevacao_frontal_barra',
  'Elevacao frontal com barra',
  'Pegada pronada, deltoide anterior.',
  'elevacao_frontal_barra',
  'ombros',
  '{}',
  'isolador',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'encolhimento_barra',
  'Encolhimento com barra',
  'Trapezio superior em amplitude curta.',
  'encolhimento_barra',
  'ombros',
  '{}',
  'isolador',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'encolhimento_halter',
  'Encolhimento com halteres',
  'Variante com halteres, melhor controle.',
  'encolhimento_halter',
  'ombros',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'crucifixo_invertido_halter',
  'Crucifixo invertido com halteres',
  'Deltoide posterior, dorso curvado a 90 graus.',
  'crucifixo_invertido_halter',
  'ombros',
  ARRAY['costas']::grupo_muscular[],
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'face_pull_corda',
  'Face pull na corda',
  'Deltoide posterior e rotadores externos.',
  'face_pull_corda',
  'ombros',
  ARRAY['costas']::grupo_muscular[],
  'puxada_horizontal',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'rosca_direta_barra',
  'Rosca direta com barra',
  'Biceps em isolamento com pegada supinada.',
  'rosca_direta_barra',
  'biceps',
  '{}',
  'isolador',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'rosca_direta_halter',
  'Rosca direta com halteres',
  'Permite supinacao no fim do movimento.',
  'rosca_direta_halter',
  'biceps',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'rosca_alternada_halter',
  'Rosca alternada com halteres',
  'Um braco por vez, foco em controle.',
  'rosca_alternada_halter',
  'biceps',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'rosca_scott_barra',
  'Rosca scott com barra',
  'Banco inclinado isola biceps.',
  'rosca_scott_barra',
  'biceps',
  '{}',
  'isolador',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'rosca_scott_halter',
  'Rosca scott com halteres',
  'Variante unilateral do scott.',
  'rosca_scott_halter',
  'biceps',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'rosca_martelo_halter',
  'Rosca martelo com halteres',
  'Pegada neutra, foco em braquial e braquiorradial.',
  'rosca_martelo_halter',
  'biceps',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'rosca_concentrada_halter',
  'Rosca concentrada',
  'Sentado, cotovelo apoiado na coxa.',
  'rosca_concentrada_halter',
  'biceps',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'rosca_21_barra',
  'Rosca 21 com barra',
  '7 reps parcial baixa, 7 parcial alta, 7 completa.',
  'rosca_21_barra',
  'biceps',
  '{}',
  'isolador',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'triceps_testa_barra',
  'Triceps testa com barra',
  'Skullcrusher classico, cabeca longa do triceps.',
  'triceps_testa_barra',
  'triceps',
  '{}',
  'isolador',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'triceps_frances_halter',
  'Triceps frances com halter',
  'Halter por cima da cabeca, cabeca longa alongada.',
  'triceps_frances_halter',
  'triceps',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'triceps_polia_barra',
  'Triceps polia com barra',
  'Pushdown classico, cabeca lateral.',
  'triceps_polia_barra',
  'triceps',
  '{}',
  'isolador',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'triceps_polia_corda',
  'Triceps polia com corda',
  'Abertura na descida ativa mais cabeca lateral.',
  'triceps_polia_corda',
  'triceps',
  '{}',
  'isolador',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'triceps_coice_halter',
  'Triceps coice com halter',
  'Kickback, contracao pico no fim.',
  'triceps_coice_halter',
  'triceps',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'triceps_banco',
  'Triceps no banco (bench dip)',
  'Peso corporal, costas perto do banco.',
  'triceps_banco',
  'triceps',
  ARRAY['peito']::grupo_muscular[],
  'empurrada_vertical',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'triceps_maquina',
  'Triceps na maquina',
  'Empurrada com tragetoria guiada.',
  'triceps_maquina',
  'triceps',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'supino_fechado_barra',
  'Supino fechado com barra',
  'Pegada estreita, foco em triceps com auxilio de peito.',
  'supino_fechado_barra',
  'triceps',
  ARRAY['peito']::grupo_muscular[],
  'empurrada_horizontal',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'agachamento_livre_barra',
  'Agachamento livre com barra',
  'Rei dos compostos. Quadriceps, gluteos e core.',
  'agachamento_livre_barra',
  'quadriceps',
  ARRAY['gluteos','posterior','core']::grupo_muscular[],
  'agachamento',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'agachamento_frontal_barra',
  'Agachamento frontal com barra',
  'Barra a frente, foco maior em quadriceps.',
  'agachamento_frontal_barra',
  'quadriceps',
  ARRAY['gluteos','core']::grupo_muscular[],
  'agachamento',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'hack_machine',
  'Hack machine',
  'Agachamento guiado em angulo, quadriceps puro.',
  'hack_machine',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'leg_press_45',
  'Leg press 45 graus',
  'Permite alta carga com baixa exigencia tecnica.',
  'leg_press_45',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'cadeira_extensora',
  'Cadeira extensora',
  'Isolador de quadriceps em maquina.',
  'cadeira_extensora',
  'quadriceps',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'agachamento_bulgaro_halter',
  'Agachamento bulgaro com halteres',
  'Unilateral. Pe traseiro elevado.',
  'agachamento_bulgaro_halter',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'afundo_barra',
  'Afundo com barra',
  'Passo a frente, joelho traseiro proximo ao solo.',
  'afundo_barra',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'afundo_halter',
  'Afundo com halteres',
  'Mesma execucao do afundo, halteres ao lado.',
  'afundo_halter',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'agachamento_smith',
  'Agachamento no Smith',
  'Barra guiada, mais seguro para iniciantes.',
  'agachamento_smith',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'passada_halter',
  'Passada (walking lunge) com halteres',
  'Versao caminhando do afundo.',
  'passada_halter',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'stiff_barra',
  'Stiff com barra',
  'Dobradica de quadril com joelho semiflexionado.',
  'stiff_barra',
  'posterior',
  ARRAY['gluteos','costas']::grupo_muscular[],
  'dobradica_quadril',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'stiff_halter',
  'Stiff com halteres',
  'Pegada neutra, amplitude maior.',
  'stiff_halter',
  'posterior',
  ARRAY['gluteos']::grupo_muscular[],
  'dobradica_quadril',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'mesa_flexora',
  'Mesa flexora',
  'Isolador de flexao do joelho.',
  'mesa_flexora',
  'posterior',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'cadeira_flexora',
  'Cadeira flexora',
  'Versao sentada, joelho a 90 graus.',
  'cadeira_flexora',
  'posterior',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'terra_romeno_barra',
  'Terra romeno com barra',
  'Variacao do terra, ipsis no posterior.',
  'terra_romeno_barra',
  'posterior',
  ARRAY['gluteos']::grupo_muscular[],
  'dobradica_quadril',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'bom_dia_barra',
  'Bom dia com barra',
  'Barra nos ombros, dobradica de quadril.',
  'bom_dia_barra',
  'posterior',
  ARRAY['gluteos','costas']::grupo_muscular[],
  'dobradica_quadril',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'hip_thrust_barra',
  'Hip thrust com barra',
  'Costas no banco, quadril em ponte com carga.',
  'hip_thrust_barra',
  'gluteos',
  ARRAY['posterior']::grupo_muscular[],
  'dobradica_quadril',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'hip_thrust_maquina',
  'Hip thrust na maquina',
  'Versao guiada, ideal para alta carga sem assistente.',
  'hip_thrust_maquina',
  'gluteos',
  ARRAY['posterior']::grupo_muscular[],
  'dobradica_quadril',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'elevacao_pelvica_halter',
  'Elevacao pelvica com halter',
  'Versao mais leve do hip thrust.',
  'elevacao_pelvica_halter',
  'gluteos',
  ARRAY['posterior']::grupo_muscular[],
  'dobradica_quadril',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'agachamento_sumo_barra',
  'Agachamento sumo com barra',
  'Pernas abertas, foco em gluteos e adutores.',
  'agachamento_sumo_barra',
  'gluteos',
  ARRAY['quadriceps']::grupo_muscular[],
  'agachamento',
  'barra'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'abducao_quadril_maquina',
  'Abducao de quadril na maquina',
  'Isolador de gluteo medio.',
  'abducao_quadril_maquina',
  'gluteos',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'kickback_maquina',
  'Glute kickback na maquina',
  'Extensao de quadril em isolamento.',
  'kickback_maquina',
  'gluteos',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'panturrilha_em_pe_maquina',
  'Panturrilha em pe na maquina',
  'Joelho extendido, gastrocnemio.',
  'panturrilha_em_pe_maquina',
  'panturrilha',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'panturrilha_sentada',
  'Panturrilha sentada',
  'Joelho flexionado, soleo.',
  'panturrilha_sentada',
  'panturrilha',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'panturrilha_smith',
  'Panturrilha no Smith',
  'Barra guiada nos ombros, em pe.',
  'panturrilha_smith',
  'panturrilha',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'panturrilha_leg_press',
  'Panturrilha no leg press',
  'Pes na ponta da plataforma, extensao de tornozelo.',
  'panturrilha_leg_press',
  'panturrilha',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'panturrilha_unilateral_halter',
  'Panturrilha unilateral com halter',
  'Um pe por vez, amplitude maxima.',
  'panturrilha_unilateral_halter',
  'panturrilha',
  '{}',
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'donkey_calf',
  'Donkey calf raise',
  'Tronco a 90 graus, gastrocnemio alongado.',
  'donkey_calf',
  'panturrilha',
  '{}',
  'isolador',
  'maquina'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'prancha_frontal',
  'Prancha frontal',
  'Isometria, core anterior.',
  'prancha_frontal',
  'core',
  '{}',
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'prancha_lateral',
  'Prancha lateral',
  'Isometria, obliquos.',
  'prancha_lateral',
  'core',
  '{}',
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'abdominal_infra',
  'Abdominal infra (eleva pernas)',
  'Foco em parte baixa do reto abdominal.',
  'abdominal_infra',
  'core',
  '{}',
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'abdominal_supra',
  'Abdominal supra (crunch)',
  'Flexao de tronco, reto abdominal.',
  'abdominal_supra',
  'core',
  '{}',
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'abdominal_oblicuo',
  'Abdominal oblicuo',
  'Cruza cotovelo com joelho oposto.',
  'abdominal_oblicuo',
  'core',
  '{}',
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'russian_twist',
  'Russian twist',
  'Rotacao de tronco com peso opcional.',
  'russian_twist',
  'core',
  '{}',
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'prancha_elevacao_perna',
  'Prancha com elevacao de perna',
  'Prancha frontal + alternancia de pernas.',
  'prancha_elevacao_perna',
  'core',
  ARRAY['gluteos']::grupo_muscular[],
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'abdominal_cabo',
  'Abdominal no cabo (cable crunch)',
  'Ajoelhado, corda atras da cabeca.',
  'abdominal_cabo',
  'core',
  '{}',
  'isolador',
  'cabo'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'ab_wheel',
  'Ab wheel rollout',
  'Rolar a roda a frente com core ativo.',
  'ab_wheel',
  'core',
  '{}',
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'hollow_hold',
  'Hollow hold',
  'Isometria de corpo todo, foco em core.',
  'hollow_hold',
  'core',
  '{}',
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'burpee',
  'Burpee',
  'Composto explosivo de corpo todo.',
  'burpee',
  'core',
  ARRAY['peito','quadriceps']::grupo_muscular[],
  'empurrada_horizontal',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'mountain_climber',
  'Mountain climber',
  'Prancha + corrida no lugar, core e cardio.',
  'mountain_climber',
  'core',
  ARRAY['quadriceps']::grupo_muscular[],
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'jumping_jack',
  'Polichinelo (jumping jack)',
  'Aquecimento dinamico classico.',
  'jumping_jack',
  'ombros',
  ARRAY['quadriceps']::grupo_muscular[],
  'isolador',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'agachamento_salto',
  'Agachamento com salto',
  'Pliometria, potencia de membros inferiores.',
  'agachamento_salto',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'kettlebell_swing',
  'Kettlebell swing',
  'Dobradica explosiva de quadril.',
  'kettlebell_swing',
  'posterior',
  ARRAY['gluteos','core']::grupo_muscular[],
  'dobradica_quadril',
  'kettlebell'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'farmers_walk',
  'Farmers walk (caminhada do fazendeiro)',
  'Carregar peso pesado em cada mao, core e grip.',
  'farmers_walk',
  'core',
  ARRAY['ombros']::grupo_muscular[],
  'isolador',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'goblet_squat',
  'Agachamento goblet com halter',
  'Halter contra o peito, agachamento profundo.',
  'goblet_squat',
  'quadriceps',
  ARRAY['gluteos','core']::grupo_muscular[],
  'agachamento',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'turkish_get_up',
  'Turkish get-up com kettlebell',
  'Levantar com kettlebell estendido. Estabilidade total.',
  'turkish_get_up',
  'core',
  ARRAY['ombros']::grupo_muscular[],
  'isolador',
  'kettlebell'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'box_jump',
  'Box jump (salto na caixa)',
  'Pliometria, potencia explosiva.',
  'box_jump',
  'quadriceps',
  ARRAY['gluteos']::grupo_muscular[],
  'agachamento',
  'peso_corporal'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

insert into public.exercises (slug, nome, descricao, gif_url, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento) values (
  'thruster_halter',
  'Thruster com halteres',
  'Agachamento + desenvolvimento em movimento continuo.',
  'thruster_halter',
  'quadriceps',
  ARRAY['ombros','triceps']::grupo_muscular[],
  'empurrada_vertical',
  'halter'
) on conflict (slug) do update set
  nome = excluded.nome,
  descricao = excluded.descricao,
  gif_url = excluded.gif_url,
  grupo_muscular_primario = excluded.grupo_muscular_primario,
  grupo_muscular_secundario = excluded.grupo_muscular_secundario,
  padrao_movimento = excluded.padrao_movimento,
  equipamento = excluded.equipamento;

commit;
