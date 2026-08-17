--
-- PostgreSQL database dump
--

\restrict akimath


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attempts (
    id uuid NOT NULL,
    player_id uuid NOT NULL,
    issued_item_id uuid,
    pack_id uuid,
    pack_index smallint,
    skill_id smallint NOT NULL,
    is_correct boolean NOT NULL,
    elapsed_ms integer NOT NULL,
    answered_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT attempts_elapsed_ms_check CHECK ((elapsed_ms >= 0)),
    CONSTRAINT attempts_one_source CHECK ((((issued_item_id IS NOT NULL) AND (pack_id IS NULL) AND (pack_index IS NULL)) OR ((issued_item_id IS NULL) AND (pack_id IS NOT NULL) AND (pack_index IS NOT NULL))))
);


--
-- Name: diag_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diag_events (
    id uuid NOT NULL,
    player_id uuid NOT NULL,
    attempt_id uuid NOT NULL,
    misconception_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: issued_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.issued_items (
    id uuid NOT NULL,
    player_id uuid NOT NULL,
    template_id text NOT NULL,
    template_version integer NOT NULL,
    seed bigint NOT NULL,
    ladder_step smallint NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: offline_packs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offline_packs (
    id uuid NOT NULL,
    player_id uuid NOT NULL,
    skill_id smallint,
    template_refs jsonb NOT NULL,
    pack_salt bytea NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL
);


--
-- Name: players; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.players (
    id uuid NOT NULL,
    age_band text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT players_age_band_known CHECK ((age_band = ANY (ARRAY['under_13'::text, '13_17'::text, 'adult'::text])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    name text NOT NULL,
    checksum text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: template_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.template_stats (
    template_id text NOT NULL,
    template_version integer NOT NULL,
    attempts bigint DEFAULT 0 NOT NULL,
    correct bigint DEFAULT 0 NOT NULL,
    sum_expected double precision DEFAULT 0 NOT NULL,
    sum_user_rating double precision DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_skills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_skills (
    player_id uuid NOT NULL,
    skill_id smallint NOT NULL,
    rating real NOT NULL,
    deviation real NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: attempts attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attempts
    ADD CONSTRAINT attempts_pkey PRIMARY KEY (id);


--
-- Name: diag_events diag_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diag_events
    ADD CONSTRAINT diag_events_pkey PRIMARY KEY (id);


--
-- Name: issued_items issued_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issued_items
    ADD CONSTRAINT issued_items_pkey PRIMARY KEY (id);


--
-- Name: offline_packs offline_packs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offline_packs
    ADD CONSTRAINT offline_packs_pkey PRIMARY KEY (id);


--
-- Name: players players_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT players_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (name);


--
-- Name: template_stats template_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_stats
    ADD CONSTRAINT template_stats_pkey PRIMARY KEY (template_id, template_version);


--
-- Name: user_skills user_skills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT user_skills_pkey PRIMARY KEY (player_id, skill_id);


--
-- Name: attempts_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attempts_created_idx ON public.attempts USING btree (created_at);


--
-- Name: attempts_player_answered_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attempts_player_answered_idx ON public.attempts USING btree (player_id, answered_at);


--
-- Name: diag_events_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX diag_events_created_idx ON public.diag_events USING btree (created_at);


--
-- Name: issued_items_player_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issued_items_player_idx ON public.issued_items USING btree (player_id);


--
-- Name: offline_packs_player_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offline_packs_player_idx ON public.offline_packs USING btree (player_id);


--
-- Name: attempts attempts_issued_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attempts
    ADD CONSTRAINT attempts_issued_item_id_fkey FOREIGN KEY (issued_item_id) REFERENCES public.issued_items(id) ON DELETE CASCADE;


--
-- Name: attempts attempts_pack_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attempts
    ADD CONSTRAINT attempts_pack_id_fkey FOREIGN KEY (pack_id) REFERENCES public.offline_packs(id) ON DELETE CASCADE;


--
-- Name: attempts attempts_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attempts
    ADD CONSTRAINT attempts_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE;


--
-- Name: diag_events diag_events_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diag_events
    ADD CONSTRAINT diag_events_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.attempts(id) ON DELETE CASCADE;


--
-- Name: diag_events diag_events_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diag_events
    ADD CONSTRAINT diag_events_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE;


--
-- Name: issued_items issued_items_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issued_items
    ADD CONSTRAINT issued_items_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE;


--
-- Name: offline_packs offline_packs_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offline_packs
    ADD CONSTRAINT offline_packs_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE;


--
-- Name: user_skills user_skills_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT user_skills_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO app_request;
GRANT USAGE ON SCHEMA public TO retention_job;


--
-- Name: TABLE attempts; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT ON TABLE public.attempts TO app_request;
GRANT SELECT,DELETE ON TABLE public.attempts TO retention_job;


--
-- Name: TABLE diag_events; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT ON TABLE public.diag_events TO app_request;
GRANT SELECT,DELETE ON TABLE public.diag_events TO retention_job;


--
-- Name: TABLE issued_items; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.issued_items TO app_request;
GRANT SELECT,DELETE ON TABLE public.issued_items TO retention_job;


--
-- Name: TABLE offline_packs; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.offline_packs TO app_request;
GRANT SELECT,DELETE ON TABLE public.offline_packs TO retention_job;


--
-- Name: TABLE players; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.players TO app_request;
GRANT SELECT,DELETE ON TABLE public.players TO retention_job;


--
-- Name: TABLE template_stats; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.template_stats TO app_request;


--
-- Name: TABLE user_skills; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.user_skills TO app_request;
GRANT SELECT,DELETE ON TABLE public.user_skills TO retention_job;


--
-- PostgreSQL database dump complete
--

\unrestrict akimath

