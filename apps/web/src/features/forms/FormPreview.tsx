// Aperçu de développement du moteur de formulaires (non livré en production : chargé seulement en mode `vite dev`).
// Champs repris de « Main courante, Nouvelle entrée » (Formulaires d'exploitation partie 2 §3 bis.1).
// Écarts assumés de l'aperçu : « Lieu » en texte (le sélecteur d'espace vient du lot Socle), « Type » limité aux
// deux libellés cités par la table (la liste réelle vient de `security_log_types` du tenant), tableau des personnes
// et services alertés non rendus. Aucun appel serveur : `log_security_event` est livré avec le lot 9.
import { useState } from 'react';
import { FormSheet } from '@keystone/ui';
import type { FormSpec } from '@keystone/domain';

const SPEC: FormSpec = {
  id: 'security-log-entry',
  title: 'Nouvelle entrée de main courante',
  sections: [
    { id: 'faits', title: 'Faits', fields: [
      { key: 'at', label: 'Date et heure', component: 'datetime', source: 'security_log.at', required: true, rules: [{ rule: 'not_future' }], help: 'Heure des faits, pas de la saisie.' },
      { key: 'backdate_reason', label: 'Motif d’antidatage', component: 'text', source: 'backdate_reason', required: false, rules: [{ rule: 'min_length', n: 10 }, { rule: 'max_length', n: 300 }], help: 'Pourquoi l’entrée est saisie après coup.' },
      { key: 'kind', label: 'Type', component: 'radio', source: 'kind', required: true, options: [{ value: 'refus_acces', label: 'Refus d’accès' }, { value: 'rectificatif', label: 'Rectificatif' }], help: 'Rectificatif corrige une entrée déjà signée.' },
      { key: 'corrects_entry_id', label: 'Entrée corrigée', component: 'text', source: 'corrects_entry_id', required: true, showIf: { field: 'kind', equals: 'rectificatif' }, help: 'L’entrée d’origine reste lisible, barrée.' },
      { key: 'severity', label: 'Gravité', component: 'radio', source: 'severity', required: true, options: [
        { value: 'info', label: 'Information' }, { value: 'minor', label: 'Mineur' }, { value: 'major', label: 'Majeur' }, { value: 'critical', label: 'Critique' }], help: 'Majeur et Critique alertent le responsable sûreté.' },
    ] },
    { id: 'lieu', title: 'Lieu et description', fields: [
      { key: 'location', label: 'Lieu', component: 'text', source: 'location_id', required: true, help: 'Scannez le point de contrôle le plus proche.' },
      { key: 'description', label: 'Description', component: 'textarea', source: 'description', required: true, rules: [{ rule: 'min_length', n: 5 }, { rule: 'max_length', n: 4000 }], help: 'Faits, sans jugement.' },
      { key: 'video_ref', label: 'Référence vidéo', component: 'text', source: 'video_ref', required: false, rules: [{ rule: 'max_length', n: 120 }], help: 'Caméra et horodatage, sans image.' },
    ] },
    { id: 'preuves', title: 'Photos', fields: [
      { key: 'photos', label: 'Photos', component: 'photo', source: 'security_log.attachment_ids', required: false, maxFiles: 10, maxBytes: 10 * 1024 * 1024,
        accept: ['image/jpeg', 'image/png', 'image/heic'], help: 'Photographiez les faits, jamais une personne identifiable sans nécessité.' },
    ] },
    { id: 'visa', title: 'Visa', fields: [
      { key: 'sig', label: 'Signature de l’agent', component: 'signature', required: true },
    ] },
  ],
};

export function FormPreview() {
  const [open, setOpen] = useState(true);
  const [sent, setSent] = useState<string | null>(null);
  return (
    <div style={{ padding: 40 }}>
      <button className="ak-btn-brand" onClick={() => setOpen(true)}>Ouvrir le formulaire</button>
      {sent && <pre style={{ marginTop: 20, fontSize: 12 }}>{sent}</pre>}
      {open && (
        <FormSheet
          spec={SPEC}
          eyebrow="Sûreté et services, main courante"
          draftKey="apercu:security-log-entry"
          signer="Agent de démonstration"
          primaryLabel="Enregistrer l’entrée"
          onClose={() => setOpen(false)}
          onSubmit={async (v) => { setSent(JSON.stringify(v, (k, x) => (k === 'image' ? '[image]' : x), 2)); }}
        />
      )}
    </div>
  );
}
