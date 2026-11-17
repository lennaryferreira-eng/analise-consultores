-- Restauração dos projetos do SABER (incidente de 17/11/2026, 02:32 BRT)
--
-- O que aconteceu: às 05:32 UTC de 17/11 (02:32 de Brasília), a coluna painel.saber_data.projects
-- foi regravada com os 40 projetos da TER (mesmos ids de painel.ter_data). As outras colunas do
-- SABER (auditorias, NPS, metas, consultores, tratativas) NÃO foram afetadas — só a lista de projetos.
--
-- De onde vem a cópia boa: bruto.saber_projeto (fonte = 'saber'), alimentada pela carga do GrowthOS.
-- Última mudança registrada: 16/11 21:32 UTC; as cargas seguintes até 22:48 UTC não viram mudanças.
-- São 311 projetos ativos (os 4 removidos antes do incidente — 2x Chiavini, Lucas Pet Market,
-- Clínica Dr Ulisses — continuam fora, como estavam).
--
-- Os filtros por data deixam o comando correto mesmo que a carga do GrowthOS rode antes da
-- restauração (ela marcaria os 311 como "sumidos" e criaria os 40 da TER como fonte saber).

-- 1) Conferência (só leitura) — deve dar 311 projetos, 0 ids da TER:
SELECT count(*) AS n,
       count(*) FILTER (WHERE projeto_id IN (
         SELECT (x->>'id')::bigint
         FROM painel.ter_data, jsonb_array_elements((projects #>> '{}')::jsonb) x)) AS ids_da_ter
FROM bruto.saber_projeto
WHERE fonte = 'saber'
  AND visto_primeiro_em < '2026-11-17T05:30:00Z'
  AND (removido_da_fonte_em IS NULL OR removido_da_fonte_em >= '2026-11-17T05:30:00Z');

-- 2) Restauração (a coluna guarda o JSON como texto dentro do jsonb, por isso o to_jsonb(...::text)):
BEGIN;
UPDATE painel.saber_data s
SET projects   = to_jsonb(sub.arr::text),
    updated_at = now()
FROM (
  SELECT jsonb_agg(dados ORDER BY projeto_id) AS arr
  FROM bruto.saber_projeto
  WHERE fonte = 'saber'
    AND visto_primeiro_em < '2026-11-17T05:30:00Z'
    AND (removido_da_fonte_em IS NULL OR removido_da_fonte_em >= '2026-11-17T05:30:00Z')
) sub
WHERE s.id = 'main';

-- 3) Conferir antes do COMMIT — deve dar 311 e nomes do SABER:
SELECT jsonb_array_length((projects #>> '{}')::jsonb) AS n_proj,
       (SELECT string_agg(x->>'nome', ' | ')
        FROM (SELECT jsonb_array_elements((projects #>> '{}')::jsonb) x LIMIT 5) z) AS amostra
FROM painel.saber_data WHERE id = 'main';
COMMIT;

-- 4) Se a carga do GrowthOS já rodou depois das 05:32 UTC, rodar a carga de novo depois do COMMIT
--    pra ela voltar a ver os 311 do SABER (e desfazer os "sumidos"/vínculos que ela tenha mexido).
