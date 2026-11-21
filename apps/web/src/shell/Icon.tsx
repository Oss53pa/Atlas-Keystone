import {
  UserRound, Radar, LayoutDashboard, FileText, Sparkles, Cog, Wrench, UsersRound, ClipboardList, CalendarRange,
  Gauge, LineChart, BookOpen, Activity, Package, Wallet, ShoppingCart, Receipt, HardHat, Star, ShieldCheck, Flame,
  Zap, Radio, AlertTriangle, FileBadge, ClipboardCheck, ListChecks, HeartPulse, GraduationCap, Recycle, BadgeCheck,
  Footprints, Inbox, Sprout, Car, DoorOpen, Users, CalendarCheck2, Split, PenTool, Hammer, Briefcase, Rocket,
  Settings, ScrollText, Printer, Smartphone, Monitor, Truck, Building2, KeyRound, Bot, BellRing, Circle,
  type LucideIcon,
} from 'lucide-react';

const MAP: Record<string, LucideIcon> = {
  'user-round': UserRound, radar: Radar, 'layout-dashboard': LayoutDashboard, 'file-text': FileText, sparkles: Sparkles,
  cog: Cog, wrench: Wrench, 'users-round': UsersRound, 'clipboard-list': ClipboardList, 'calendar-range': CalendarRange,
  gauge: Gauge, 'line-chart': LineChart, 'book-open': BookOpen, activity: Activity, package: Package, wallet: Wallet,
  'shopping-cart': ShoppingCart, receipt: Receipt, 'hard-hat': HardHat, star: Star, 'shield-check': ShieldCheck,
  flame: Flame, zap: Zap, radio: Radio, 'alert-triangle': AlertTriangle, 'file-badge': FileBadge,
  'clipboard-check': ClipboardCheck, 'list-checks': ListChecks, 'heart-pulse': HeartPulse,
  'graduation-cap': GraduationCap, recycle: Recycle, 'badge-check': BadgeCheck, footprints: Footprints, inbox: Inbox,
  sprout: Sprout, car: Car, 'door-open': DoorOpen, users: Users, 'calendar-check-2': CalendarCheck2, split: Split,
  'pen-tool': PenTool, hammer: Hammer, briefcase: Briefcase, rocket: Rocket, settings: Settings,
  'scroll-text': ScrollText, printer: Printer, smartphone: Smartphone, monitor: Monitor, truck: Truck,
  'building-2': Building2, 'key-round': KeyRound, bot: Bot, 'bell-ring': BellRing,
};

export function Icon({ name, size = 14 }: { name: string; size?: number }) {
  const C = MAP[name] ?? Circle;
  return <C size={size} strokeWidth={1.75} aria-hidden className="ak-ico" />;
}
