-- ============================================================
-- SONNETTE SPELEO - Schema complet pour une nouvelle installation
-- A coller tel quel dans Supabase > SQL Editor > Run
-- AVANT : remplacer admin@example.org (2 occurrences dans ce
-- fichier et dans le bloc CONFIG de index.html) par l'email
-- que vous choisirez pour le compte admin de votre club.
-- ============================================================

-- 1. Membres du club
create table if not exists membres (
  id uuid primary key default gen_random_uuid(),
  prenom text not null,
  nom text not null,
  date_naissance date,
  niveau text not null default 'Autonome',   -- Debutant | Initie | Autonome | Confirme | Initiateur | Moniteur
  telephone text default '',
  contact_urgence text default '',           -- personne a prevenir : nom + telephone
  callmebot_key text default '',             -- cle CallMeBot pour l'alerte WhatsApp automatique (optionnel)
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

-- 2. Vehicules (coches dans une sortie pour aider les secours a localiser le groupe)
create table if not exists vehicules (
  id uuid primary key default gen_random_uuid(),
  modele text not null,
  immatriculation text not null default '',
  options text default '',                 -- coffre de toit, attelage, 7 places...
  proprietaire text default '',
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

-- 3. Grottes (fiches reutilisables)
create table if not exists grottes (
  id uuid primary key default gen_random_uuid(),
  nom text not null,                       -- avec l'article : "de la Balme", "d'Orgnac"
  type_cavite text not null default 'grotte',
  departement text default '',
  emplacement text default '',             -- commune, acces, parking
  gps text default '',                     -- point GPS de l'entree, ex "45.123456, 4.567890"
  profondeur text default '',
  duree text default '',                   -- duree habituelle des sorties, ex "4 a 6 h"
  difficulte text default '',              -- Facile | Moyenne | Difficile | Tres difficile
  style text default '',                   -- Initiation | Technique | Initiation et technique
  notes text default '',
  created_at timestamptz not null default now()
);

-- 4. Sorties (journal de securite : on ne supprime jamais, on annule)
create table if not exists sorties (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  date_sortie date not null default current_date,
  type_cavite text not null default 'grotte',
  nom_cavite text not null default '',
  departement text default '',
  objectif text default '',
  club text default '',
  nb_exterieurs int not null default 0,
  type_sortie text default '',
  connaissance text default '',
  materiel text default '',
  grotte_id uuid references grottes(id) on delete set null,
  gps text default '',
  vehicules jsonb not null default '[]',
  heure_entree time,
  heure_sortie_prevue time,
  heure_secours time,
  sonnette_nom text default '',
  sonnette_tel text default '',
  participants jsonb not null default '[]',
  message text default '',
  statut text not null default 'prevue',   -- prevue | sous_terre | sortis | annulee
  entree_reelle timestamptz,
  sortie_reelle timestamptz,
  alerte_envoyee timestamptz               -- rempli par le rappel n8n : une seule alerte par sortie
);

create index if not exists idx_sorties_statut on sorties (statut, date_sortie desc);

-- 5. Qui est admin ? Le compte dont l'email est celui-ci (a remplacer) :
create or replace function is_admin() returns boolean
language sql stable as $$
  select coalesce(auth.jwt()->>'email', '') = 'admin@example.org'
$$;

-- 6. Securite (RLS) : rien n'est accessible sans etre connecte.
--    Lecture pour tous les connectes ; gestion des fiches reservee a l'admin ;
--    les sorties sont declarees et suivies par tous, supprimees par personne.
alter table membres enable row level security;
alter table vehicules enable row level security;
alter table grottes enable row level security;
alter table sorties enable row level security;

create policy "membres_select" on membres for select to authenticated using (true);
create policy "membres_insert" on membres for insert to authenticated with check (is_admin());
create policy "membres_update" on membres for update to authenticated using (is_admin());
create policy "membres_delete" on membres for delete to authenticated using (is_admin());

create policy "vehicules_select" on vehicules for select to authenticated using (true);
create policy "vehicules_insert" on vehicules for insert to authenticated with check (is_admin());
create policy "vehicules_update" on vehicules for update to authenticated using (is_admin());
create policy "vehicules_delete" on vehicules for delete to authenticated using (is_admin());

create policy "grottes_select" on grottes for select to authenticated using (true);
create policy "grottes_insert" on grottes for insert to authenticated with check (is_admin());
create policy "grottes_update" on grottes for update to authenticated using (is_admin());
create policy "grottes_delete" on grottes for delete to authenticated using (is_admin());

create policy "sorties_select" on sorties for select to authenticated using (true);
create policy "sorties_insert" on sorties for insert to authenticated with check (true);
create policy "sorties_update" on sorties for update to authenticated using (true);
-- Pas de policy delete sur sorties : le journal de securite est conserve.

-- 7. Exemple d'import de membres (adapter puis decommenter, ou saisir dans l'app)
-- insert into membres (prenom, nom, date_naissance, niveau, telephone, contact_urgence) values
-- ('Prenom','Nom','1980-01-01','Initiateur','06 00 00 00 00','Personne a prevenir 06 00 00 00 00');

-- 8. Reglages des alertes automatiques + canaux d'alerte (onglet admin "Alertes")
create table if not exists reglages (
  id int primary key,
  alerte_email boolean not null default true,
  alerte_whatsapp boolean not null default true,
  emails_alerte text default ''            -- destinataires des emails d'alerte, separes par des virgules
);

insert into reglages (id) values (1) on conflict (id) do nothing;

alter table reglages enable row level security;
create policy "reglages_select" on reglages for select to authenticated using (true);
create policy "reglages_update" on reglages for update to authenticated using (is_admin());

-- Canaux d'alerte : sites et numeros pour declencher les secours (modifiables dans l'app).
-- Valeurs par defaut pour la France : adaptez-les a votre pays dans l'onglet Alertes.
create table if not exists canaux_alerte (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  valeur text not null,                    -- numero de telephone, ou adresse https://...
  created_at timestamptz not null default now()
);

insert into canaux_alerte (nom, valeur)
select v.n, v.va from (values
  ('SSF Alert', 'https://ssfalert.fr'),
  ('Numéro d''urgence européen', '112'),
  ('Spéléo Secours Français', '0800 121 123')
) as v(n, va)
where not exists (select 1 from canaux_alerte);

alter table canaux_alerte enable row level security;
create policy "canaux_select" on canaux_alerte for select to authenticated using (true);
create policy "canaux_insert" on canaux_alerte for insert to authenticated with check (is_admin());
create policy "canaux_update" on canaux_alerte for update to authenticated using (is_admin());
create policy "canaux_delete" on canaux_alerte for delete to authenticated using (is_admin());
