// The top banner ad, shown only inside the native apps, Android and iOS (through the AdMob Capacitor plugin). In a
// browser there are no ads. The page leaves room for the banner: its height is set on the root
// element as --ad-top, so the header and the city start below it.
import { CONFIG } from './config.js';

// No banner is showing: the page takes no room for one.
function noBanner() {
  document.documentElement.style.setProperty('--ad-top', '0px');
  document.documentElement.style.setProperty('--ad-min', '0px');
}

// The ad unit IDs for the platform we run on, or test IDs when CONFIG.admob.testing is on.
function adUnits() {
  const a = CONFIG.admob;
  const ios = window.Capacitor?.getPlatform?.() === 'ios';
  const own = ios ? a.ios : a.android;
  return {
    ios,
    banner: a.testing ? (ios ? a.iosTestBannerId : a.testBannerId) : own.bannerId,
    rewarded: a.testing ? (ios ? a.iosRewardedTestId : a.rewardedTestId) : own.rewardedId,
  };
}

// iOS asks the player once whether apps may track them (App Tracking Transparency). The answer
// only decides whether ads are personalised; ads are shown either way.
async function askTracking(AdMob) {
  try {
    const status = await AdMob.trackingAuthorizationStatus?.();
    if (status?.status === 'notDetermined') await AdMob.requestTrackingAuthorization();
  } catch {
    // Not fatal: ads still load, just not personalised.
  }
}

export async function startAds() {
  const capacitor = window.Capacitor;
  if (!capacitor?.isNativePlatform?.()) return;
  const AdMob = capacitor.Plugins?.AdMob;
  if (!AdMob) return;
  // Transparent page background, so the banner shows where the page's background would be.
  document.documentElement.classList.add('native');
  if (capacitor.getPlatform?.() === 'ios') document.documentElement.classList.add('ios');
  document.body.classList.add('native');
  try {
    const units = adUnits();
    if (!units.banner) return noBanner();
    if (units.ios) await askTracking(AdMob);
    await AdMob.initialize({});
    await AdMob.addListener('bannerAdSizeChanged', (info) => {
      document.documentElement.style.setProperty('--ad-top', `${info.height}px`);
    });
    await AdMob.addListener('bannerAdFailedToLoad', () => {
      noBanner();
    });
    await AdMob.showBanner({
      adId: units.banner,
      adSize: 'ADAPTIVE_BANNER',
      position: 'TOP_CENTER',
      isTesting: CONFIG.admob.testing,
    });
  } catch {
    // Ads are optional: if they cannot start, the game runs without them.
    noBanner();
  }
}

// Rewarded video: prepared in the background, and shown when the player asks for a free run.
// Watching it to the end calls the reward callback once.
let rewardAds = null;
let rewardReady = false;
let rewardCallback = null;

function rewardOptions() {
  return {
    adId: adUnits().rewarded,
    isTesting: CONFIG.admob.testing,
  };
}

function prepareReward() {
  rewardReady = false;
  rewardAds?.prepareRewardVideoAd(rewardOptions()).catch(() => {});
}

export async function startRewardAds() {
  const capacitor = window.Capacitor;
  if (!capacitor?.isNativePlatform?.()) return;
  rewardAds = capacitor.Plugins?.AdMob ?? null;
  if (!rewardAds || !adUnits().rewarded) {
    rewardAds = null; // no rewarded unit on this platform
    return;
  }
  try {
    await rewardAds.addListener('onRewardedVideoAdLoaded', () => { rewardReady = true; });
    await rewardAds.addListener('onRewardedVideoAdFailedToLoad', () => setTimeout(prepareReward, 30000));
    await rewardAds.addListener('onRewardedVideoAdReward', () => rewardCallback?.());
    await rewardAds.addListener('onRewardedVideoAdDismissed', prepareReward);
    prepareReward();
  } catch {
    rewardAds = null;
  }
}

// True when a rewarded video is loaded and can be shown now.
export function rewardReadyNow() {
  return Boolean(rewardAds) && rewardReady;
}

// Shows the rewarded video. The callback runs when the player has watched it to the end.
export function showRewardAd(onReward) {
  if (!rewardReadyNow()) return;
  rewardCallback = onReward;
  rewardAds.showRewardVideoAd().catch(() => {});
}

