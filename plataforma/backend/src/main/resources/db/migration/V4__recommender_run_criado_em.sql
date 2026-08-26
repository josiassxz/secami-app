-- O cliente envia seu próprio timestamp de criação ("criado_em") no push do
-- recomendador — mesma necessidade já resolvida em V3 para routine/set_log.
ALTER TABLE recommender_run ADD COLUMN criado_em timestamptz;
