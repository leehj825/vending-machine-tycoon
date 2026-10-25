// The top banner ad, shown only inside the Android app (through the AdMob Capacitor plugin). In a
// browser there are no ads. The page leaves room for the banner: its height is set on the root
// element as --ad-top, so the header and the city start below it.
import { CONFIG } from './config.js';

export async function startAds() {
  const capacitor = window.Capacitor;
  if (!capacitor?.isNativePlatform?.()) return;
  const AdMob = capacitor.Plugins?.AdMob;
  if (!AdMob) return;
  document.body.classList.add('native');
  try {
    await AdMob.initialize({});
    await AdMob.addListener('bannerAdSizeChanged', (info) => {
      document.documentElement.style.setProperty('--ad-top', `${info.height}px`);
    });
    await AdMob.addListener('bannerAdFailedToLoad', () => {
      document.documentElement.style.setProperty('--ad-top', '0px');
    });
    await AdMob.showBanner({
      adId: CONFIG.admob.testing ? CONFIG.admob.testBannerId : CONFIG.admob.bannerId,
      adSize: 'ADAPTIVE_BANNER',
      position: 'TOP_CENTER',
      isTesting: CONFIG.admob.testing,
    });
  } catch {
    // Ads are optional: if they cannot start, the game runs without them.
    document.documentElement.style.setProperty('--ad-top', '0px');
  }
}
