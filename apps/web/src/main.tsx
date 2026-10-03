import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@keystone/ui/styles/keystone.css';
import './styles/global.css';
import { App } from './App.tsx';
import { OccupantPortal } from './features/portal/OccupantPortal.tsx';
import { ContractorApp } from './features/contractor-app/ContractorApp.tsx';

// Portail occupant public (sans compte) si l'URL porte ?qr=… / ?suivi=… / ?portail ; espace prestataire si ?prestataire
const params = new URLSearchParams(window.location.search);
const isPortal = params.has('qr') || params.has('suivi') || params.has('portail');
const isContractor = params.has('prestataire');

createRoot(document.getElementById('root')!).render(
  <StrictMode>{isContractor ? <ContractorApp /> : isPortal ? <OccupantPortal /> : <App />}</StrictMode>,
);
