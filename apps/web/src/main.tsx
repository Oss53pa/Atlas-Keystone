import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@keystone/ui/styles/keystone.css';
import './styles/global.css';
import { App } from './App.tsx';
import { OccupantPortal } from './features/portal/OccupantPortal.tsx';
import { ContractorApp } from './features/contractor-app/ContractorApp.tsx';
import { TenantApp } from './features/tenant-portal/TenantApp.tsx';
import { TechApp } from './features/tech-app/TechApp.tsx';

// Portail occupant public (sans compte) si l'URL porte ?qr=… / ?suivi=… / ?portail ; espace prestataire si ?prestataire ; portail locataire si ?locataire ; app technicien si ?technicien
const params = new URLSearchParams(window.location.search);
const isPortal = params.has('qr') || params.has('suivi') || params.has('portail');
const isContractor = params.has('prestataire');
const isLessee = params.has('locataire');
const isTech = params.has('technicien');

createRoot(document.getElementById('root')!).render(
  <StrictMode>{isTech ? <TechApp /> : isLessee ? <TenantApp /> : isContractor ? <ContractorApp /> : isPortal ? <OccupantPortal /> : <App />}</StrictMode>,
);
