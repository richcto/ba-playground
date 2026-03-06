import {
  createUnifiedTheme,
  createBaseThemeOptions,
  palettes,
  genPageTheme,
  shapes,
} from '@backstage/theme';

// British Airways brand colors
const BA_RED = '#EB2226';
const BA_NAVY = '#01295C';
const BA_NAVY_LIGHT = '#2d4a7c';

// Page header themes - all use BA colors
const baPageTheme = {
  home: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave,
    options: { fontColor: '#FFFFFF' },
  }),
  documentation: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave2,
    options: { fontColor: '#FFFFFF' },
  }),
  tool: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.round,
    options: { fontColor: '#FFFFFF' },
  }),
  service: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave,
    options: { fontColor: '#FFFFFF' },
  }),
  website: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave,
    options: { fontColor: '#FFFFFF' },
  }),
  library: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave,
    options: { fontColor: '#FFFFFF' },
  }),
  other: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave,
    options: { fontColor: '#FFFFFF' },
  }),
  app: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave,
    options: { fontColor: '#FFFFFF' },
  }),
  apis: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave2,
    options: { fontColor: '#FFFFFF' },
  }),
  card: genPageTheme({
    colors: [BA_NAVY, BA_RED],
    shape: shapes.wave,
    options: { fontColor: '#FFFFFF' },
  }),
};

const baPalette = {
  ...palettes.light,
  primary: {
    main: BA_RED,
    light: '#ff5a4d',
    dark: '#b31a00',
  },
  secondary: {
    main: BA_NAVY,
    light: BA_NAVY_LIGHT,
    dark: '#000d24',
  },
  navigation: {
    background: BA_NAVY,
    indicator: BA_RED,
    color: '#b5b5b5',
    selectedColor: '#ffffff',
    navItem: {
      hoverBackground: 'rgba(255,255,255,0.12)',
    },
    submenu: {
      background: '#001a3d',
    },
  },
  bursts: {
    ...palettes.light.bursts,
    gradient: {
      linear: `linear-gradient(-137deg, ${BA_NAVY} 0%, ${BA_RED} 100%)`,
    },
  },
  tabbar: {
    indicator: BA_RED,
  },
};

export const britishAirwaysTheme = createUnifiedTheme(
  createBaseThemeOptions({
    palette: baPalette,
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif',
    pageTheme: baPageTheme,
  }),
);
