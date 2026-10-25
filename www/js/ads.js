// The top banner ad, shown only inside the Android app (through the AdMob Capacitor plugin). In a
// browser there are no ads. The page leaves room for the banner: its height is set on the root
// element as --ad-top, so the header and the city start below it.
import { CONFIG } from './config.js';

export async function startAds() {
  const capacitor = window.Capacitor;
  if (!capacitor?.isNativePlatform?.()) return;
  const AdMob = capacitor.Plugins?.AdMob;
  if (!AdMob) return;
  // Transparent page background, so the banner shows where the page's background would be.
  document.documentElement.classList.add('native');
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

// Rewarded video: prepared in the background, and shown when the player asks for a free run.
// Watching it to the end calls the reward callback once.
let rewardAds = null;
let rewardReady = false;
let rewardCallback = null;

function rewardOptions() {
  return {
    adId: CONFIG.admob.testing ? CONFIG.admob.rewardedTestId : CONFIG.admob.rewardedId,
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
  if (!rewardAds) return;
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

