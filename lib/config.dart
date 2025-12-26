import 'package:flutter/material.dart';

/// Central configuration file for all constants used throughout the app
class AppConfig {
  AppConfig._(); // Private constructor to prevent instantiation

  // ============================================================================
  // FONT SIZES - Standardized font sizes for consistent UI
  // ============================================================================
  
  /// Font size factors for responsive sizing (relative to smaller screen dimension)
  static const double fontSizeFactorLarge = 0.045;      // Headers, titles
  static const double fontSizeFactorMedium = 0.035;    // Subheaders, important text
  static const double fontSizeFactorNormal = 0.032;    // Body text, labels
  static const double fontSizeFactorSmall = 0.025;     // Secondary text, captions
  static const double fontSizeFactorTiny = 0.02;       // Very small text
  
  /// Font size min/max multipliers (relative to smaller dimension)
  static const double fontSizeMinMultiplier = 0.025;
  static const double fontSizeMaxMultiplier = 0.065;
  
  /// Fixed font sizes for non-responsive elements
  static const double fontSizeFixedLarge = 18.0;
  static const double fontSizeFixedMedium = 16.0;
  static const double fontSizeFixedNormal = 14.0;
  static const double fontSizeFixedSmall = 12.0;
  static const double fontSizeFixedTiny = 10.0;
  
  // ============================================================================
  // UI CONSTANTS - Spacing, sizes, colors
  // ============================================================================
  
  /// Standard padding values
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  /// Spacing factors for SizedBox (relative to smaller screen dimension)
  static const double spacingFactorTiny = 0.001; // Very small spacing (1px on 1000px screen)
  static const double spacingFactorSmall = 0.002; // Small spacing (2px on 1000px screen)
  static const double spacingFactorMedium = 0.008; // Medium spacing (8px on 1000px screen)
  static const double spacingFactorLarge = 0.012; // Large spacing (12px on 1000px screen)
  static const double spacingFactorXLarge = 0.016; // Extra large spacing (16px on 1000px screen)
  
  /// Common border width factors (reused across components)
  static const double borderWidthFactorTiny = spacingFactorTiny; // 0.001 - Very thin borders
  static const double borderWidthFactorSmall = spacingFactorSmall; // 0.002 - Small borders
  static const double borderWidthFactorMedium = spacingFactorSmall * 2; // 0.004 - Medium borders
  
  /// Common border radius factors (reused across components)
  static const double borderRadiusFactorTiny = spacingFactorTiny; // 0.001 - Very small radius
  static const double borderRadiusFactorSmall = spacingFactorSmall * 4; // 0.008 - Small radius
  static const double borderRadiusFactorMedium = spacingFactorXLarge; // 0.016 - Medium radius
  static const double borderRadiusFactorLarge = spacingFactorXLarge * 2; // 0.032 - Large radius
  
  /// Border radius values
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  
  /// Icon sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  
  /// Button sizes
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 36.0;
  
  /// GameButton sizes (used in fleet manager and other screens)
  static const double gameButtonPaddingHorizontalFactor = 0.01; // Horizontal padding as factor of screen width
  static const double gameButtonPaddingVerticalFactor = 0.01; // Vertical padding as factor of smaller screen dimension
  static const double gameButtonBorderRadius = 8.0;
  static const double gameButtonIconSizeFactor = 0.05; // Icon size as factor of smaller screen dimension
  static const double gameButtonIconSizeMultiplier = 1.5; // Multiplier for buy truck button icon (larger than normal)
  static const double gameButtonFontSizeFactor = 0.03; // Font size factor (responsive) - uses fontSizeFactorNormal by default
  
  /// SmallGameButton sizes (used in dialogs)
  static const double smallGameButtonPaddingHorizontalFactor = 0.01; // Horizontal padding as factor of screen width
  static const double smallGameButtonPaddingVerticalFactor = 0.01; // Vertical padding as factor of smaller screen dimension
  static const double smallGameButtonBorderRadius = 8.0;
  static const double smallGameButtonIconSizeFactor = 0.04; // Icon size as factor of smaller screen dimension
  static const double smallGameButtonFontSizeFactor = 0.025; // Font size factor (responsive) - uses fontSizeFactorSmall by default
  
  /// Truck selector card sizes (fleet manager screen)
  static const double truckCardWidthFactor = 0.20; // Card width as factor of screen width
  static const double truckCardHeightFactor = 0.18; // Card container height as factor of smaller screen dimension
  static const double truckCardPaddingFactor = spacingFactorSmall * 4; // 0.008 - Internal padding of truck card
  static const double truckCardBorderRadiusFactor = borderWidthFactorSmall; // 0.002 - Border radius of truck card
  static const double truckCardMarginHorizontalFactor = spacingFactorTiny; // 0.001 - Horizontal margin between cards
  
  /// Truck icon sizes
  static const double truckIconContainerSizeFactor = 0.05; // Icon container size as factor of smaller screen dimension
  static const double truckIconSizeFactor = 0.05; // Icon size as factor of smaller screen dimension
  static const double truckIconContainerBorderRadiusFactor = borderRadiusFactorTiny; // 0.001 - Border radius of icon container
  
  /// Truck name and status sizes
  static const double truckNameFontSizeFactor = fontSizeFactorMedium; // 0.035 - Truck name font size factor
  static const double truckStatusFontSizeFactor = fontSizeFactorTiny; // 0.02 - Status badge font size factor
  static const double truckStatusPaddingHorizontalFactor = borderWidthFactorSmall; // 0.002 - Status badge horizontal padding
  static const double truckStatusPaddingVerticalFactor = spacingFactorTiny; // 0.001 - Status badge vertical padding
  static const double truckStatusBorderRadiusFactor = borderRadiusFactorTiny; // 0.001 - Status badge border radius
  
  // ============================================================================
  // MACHINE ROUTE CARD CONSTANTS
  // ============================================================================
  
  /// Machine route card container
  static const double machineRouteCardMarginHorizontalFactor = spacingFactorSmall * 4; // 0.008 - Horizontal margin
  static const double machineRouteCardMarginVerticalFactor = borderWidthFactorMedium; // 0.004 - Vertical margin
  static const double machineRouteCardBorderRadiusFactor = borderRadiusFactorMedium; // 0.016 - Border radius
  static const double machineRouteCardBorderWidthFactor = borderWidthFactorSmall; // 0.002 - Border width
  static const double machineRouteCardShadowOffsetFactor = borderWidthFactorMedium; // 0.004 - Shadow offset
  static const double machineRouteCardShadowBlurFactor = spacingFactorSmall * 4; // 0.008 - Shadow blur radius
  static const double machineRouteCardPaddingFactor = borderRadiusFactorMedium; // 0.016 - Padding
  
  /// Machine route card icon container
  static const double machineRouteCardIconContainerSizeFactor = 0.048; // Icon container size as factor of smaller screen dimension
  static const double machineRouteCardIconContainerBorderWidthFactor = borderWidthFactorSmall; // 0.002 - Icon container border width
  static const double machineRouteCardIconSizeFactor = fontSizeFactorNormal * 0.96; // 0.024 - Icon size (reuse 0.024 pattern)
  
  /// Machine route card spacing
  static const double machineRouteCardIconSpacingFactor = borderRadiusFactorMedium; // 0.016 - Spacing between icon and text
  static const double machineRouteCardTextSpacingFactor = borderWidthFactorSmall; // 0.002 - Spacing between text lines
  static const double machineRouteCardInventoryIconSpacingFactor = borderWidthFactorSmall; // 0.002 - Spacing between inventory icon and text
  
  /// Machine route card text sizes
  static const double machineRouteCardTitleFontSizeFactor = fontSizeFactorMedium; // 0.035 - Title font size
  static const double machineRouteCardZoneFontSizeFactor = fontSizeFactorNormal; // 0.032 - Zone text font size
  static const double machineRouteCardStockFontSizeFactor = fontSizeFactorMedium; // 0.035 - Stock text font size
  static const double machineRouteCardInventoryIconSizeFactor = borderRadiusFactorMedium; // 0.016 - Inventory icon size
  
  /// Machine route card remove button
  static const double machineRouteCardRemoveButtonBorderRadiusFactor = borderRadiusFactorMedium; // 0.016 - Remove button border radius
  static const double machineRouteCardRemoveButtonBorderWidthFactor = spacingFactorTiny; // 0.001 - Remove button border width
  static const double machineRouteCardRemoveIconSizeFactor = fontSizeFactorLarge; // 0.045 - Remove icon size
  
  /// Route list container
  static const double routeListMaxHeightFactor = 0.6; // Max height of route list as factor of screen height
  static const double routeListEmptyIconSizeFactor = 0.064; // Empty route icon size as factor of smaller screen dimension
  
  /// Truck cargo display
  static const double truckCargoMaxItemWidthFactor = 0.4; // Max width of cargo item as factor of screen width
  
  // ============================================================================
  // LOAD CARGO DIALOG CONSTANTS
  // ============================================================================
  
  /// Load cargo dialog quantity display
  static const double loadCargoQuantityContainerPaddingFactor = borderRadiusFactorMedium; // 0.016 - Container padding
  static const double loadCargoQuantityBorderWidthFactor = borderWidthFactorSmall; // 0.002 - Border width
  
  // ============================================================================
  // NUMBER PAD CONSTANTS
  // ============================================================================
  
  /// Number pad text field (relative to dialog width or screen)
  static const double numberPadTextFieldPaddingFactor = 0.02; // Text field padding
  static const double numberPadTextFieldBorderRadiusFactor = 0.01; // Text field border radius
  static const double numberPadTextFieldBorderWidthFactor = 0.002; // Text field border width
  
  /// Number pad spacing
  static const double numberPadSpacingFactor = 0.02; // Spacing between text field and pad grid
  
  /// Number pad container (relative to dialog width or screen)
  static const double numberPadContainerPaddingFactor = 0.01; // Pad container padding
  static const double numberPadContainerBorderRadiusFactor = 0.01; // Pad container border radius
  static const double numberPadContainerBorderWidthFactor = 0.001; // Pad container border width
  
  /// Number pad buttons (relative to dialog width or screen)
  static const double numberPadButtonSizeFactor = 0.10; // Button size
  static const double numberPadButtonFontSizeFactor = 0.06; // Button font size (for dialog-based)
  static const double numberPadButtonBorderRadiusMultiplier = 0.2; // Button border radius as multiplier of button size
  static const double numberPadButtonBorderWidthMultiplier = 0.02; // Button border width as multiplier of button size
  static const double numberPadButtonPaddingMultiplier = 0.1; // Button padding as multiplier of button size
  
  // ============================================================================
  // EFFICIENCY STATS CONSTANTS
  // ============================================================================
  
  /// Efficiency stat item
  static const double efficiencyStatIconSizeFactor = machineRouteCardIconSizeFactor; // 0.024 - Stat icon size (reuse)
  
  /// Route efficiency font sizes
  static const double routeEfficiencyTitleFontSizeFactor = fontSizeFactorNormal; // 0.025 - Route efficiency card title font size
  static const double routeEfficiencyValueFontSizeFactor = fontSizeFactorNormal; // 0.025 - Route efficiency rating value font size (Great, Good, Fair, Poor)
  static const double routeEfficiencyLabelFontSizeFactor = fontSizeFactorNormal; // 0.025 - Route efficiency label font size (Efficiency, Total Distance, etc.)
  
  // ============================================================================
  // SMALL GAME BUTTON (ROUTE PLANNER) CONSTANTS
  // ============================================================================
  
  /// Small game button (used in route planner dialogs)
  static const double routePlannerSmallButtonPressedMarginFactor = spacingFactorTiny * 3; // 0.003 - Pressed margin
  static const double routePlannerSmallButtonShadowOffsetFactor = spacingFactorTiny * 3; // 0.003 - Shadow offset
  static const double routePlannerSmallButtonBorderWidthFactor = spacingFactorTiny * 1.5; // 0.0015 - Border width
  
  /// Bottom navigation bar sizes
  static const double bottomNavBarHeightFactor = 0.20; // Height as factor of smaller screen dimension
  
  /// Tab button sizes (HQ, City, Fleet, Market buttons) - Removed min/max duplicates
  static const double tabButtonHeightFactor = 0.20; // Height as factor of smaller screen dimension
  
  /// Tab button icon size (for fallback icons) - Removed min/max duplicates
  static const double tabButtonIconSizeFactor = 0.20; // Icon size as factor of smaller screen dimension
  
  /// Save/Exit button sizes - Removed min/max duplicates
  static const double saveExitButtonHeightFactor = 0.10; // Height as factor of smaller screen dimension
  static const double saveExitButtonWidthFactor = 0.10; // Width as factor of screen width
  
  /// Top status bar boxes (cash, reputation, time)
  static const double statusCardWidthFactor = 0.75; // Width as factor of smaller dimension (0.25 * 3.0)
  static const double statusCardWidthMinFactor = 0.25; // Minimum width as factor of smaller dimension
  static const double statusCardWidthMaxFactor = 0.25; // Maximum width as factor of smaller dimension
  static const double statusCardHeightRatio = 1.0; // Height ratio relative to card width
  
  /// Status card icon settings - Removed min/max duplicates
  static const double statusCardIconSizeFactor = 0.60; // Icon size factor relative to card width
  static const double statusCardIconTopPositionFactor = 0.05; // Icon top position as factor of card height (relative to card height)
  
  /// Status card text settings
  static const double statusCardTextSizeFactor = 0.030; // Text font size factor (relative to smaller screen dimension)
  static const double statusCardTextBottomPositionFactor = 0.05; // Text bottom position as factor of card height (relative to card height)
  
  /// Status card padding and spacing - Removed min/max duplicates
  static const double statusCardPaddingFactor = 0.01; // Internal padding factor relative to card width
  static const double statusBarContainerPaddingFactor = spacingFactorTiny; // 0.001 - Container padding around status bar (reuse)
  
  /// Card dimensions
  static const double cardBorderWidth = 2.0;
  static const double cardElevation = 4.0;
  
  /// Animation durations
  static const Duration animationDurationFast = Duration(milliseconds: 100);
  static const Duration animationDurationMedium = Duration(milliseconds: 200);
  static const Duration animationDurationSlow = Duration(milliseconds: 300);
  
  /// Snackbar durations
  static const Duration snackbarDurationShort = Duration(seconds: 2);
  static const Duration snackbarDurationLong = Duration(seconds: 3);
  
  // ============================================================================
  // GAME CONSTANTS - Prices, capacities, limits
  // ============================================================================
  
  /// Machine purchase prices
  static const double machineBasePrice = 400.0;
  
  /// Truck prices
  static const double truckPrice = 500.0;
  
  /// Warehouse capacity
  static const int warehouseMaxCapacity = 1000;
  
  // ============================================================================
  // MACHINE STATUS POPUP CONSTANTS
  // ============================================================================
  
  /// Machine status popup dialog dimensions (relative to screen)
  static const double machineStatusDialogWidthFactor = 0.9; // 90% of screen width
  static const double machineStatusDialogHeightFactor = 0.8; // 80% of screen height
  static const double machineStatusDialogInsetPaddingFactor = 0.04; // Inset padding relative to screen
  
  /// Machine status popup sizing (relative to dialog width) - No min/max to avoid small screen restrictions
  static const double machineStatusDialogBorderRadiusFactor = 0.04; // Border radius as factor of dialog width
  static const double machineStatusDialogPaddingFactor = 0.04; // Padding as factor of dialog width
  static const double machineStatusDialogImageHeightFactor = 0.5; // Image height as factor of dialog width
  
  /// Machine status popup header
  static const double machineStatusDialogCloseButtonSizeFactor = 0.08; // Close button icon size as factor of dialog width
  static const double machineStatusDialogCloseButtonPaddingFactor = 0.3; // Close button padding as factor of padding
  static const double machineStatusDialogErrorTextFontSizeFactor = 0.045; // Error text font size as factor of dialog width
  static const double machineStatusDialogHeaderImageTopPaddingFactor = 0.5; // Image top padding for close button as factor of padding
  
  /// Machine status popup content section
  static const double machineStatusDialogZoneIconContainerSizeFactor = 0.05; // Zone icon container size as factor of dialog width
  static const double machineStatusDialogZoneIconSizeFactor = 0.04; // Zone icon size as factor of dialog width
  static const double machineStatusDialogZoneIconSpacingFactor = 0.01; // Spacing between zone icon and name as factor of dialog width
  static const double machineStatusDialogMachineNameFontSizeFactor = 0.05; // Machine name font size as factor of dialog width
  static const double machineStatusDialogSectionSpacingFactor = 0.01; // Spacing between sections as factor of dialog width
  static const double machineStatusDialogStockTextFontSizeFactor = 0.04; // Stock text font size as factor of dialog width
  static const double machineStatusDialogStockProgressSpacingFactor = 0.01; // Spacing before progress bar as factor of dialog width
  static const double machineStatusDialogProgressBarHeightFactor = 0.02; // Progress bar height as factor of dialog width
  static const double machineStatusDialogInfoContainerPaddingFactor = 0.01; // Info container padding as factor of dialog width
  static const double machineStatusDialogInfoContainerBorderRadiusFactor = 0.02; // Info container border radius as factor of dialog width
  static const double machineStatusDialogInfoLabelFontSizeFactor = 0.04; // Info label font size as factor of dialog width
  static const double machineStatusDialogInfoValueFontSizeFactor = 0.04; // Info value font size as factor of dialog width
  static const double machineStatusDialogDividerHeightFactor = 0.003; // Divider height as factor of dialog width
  static const double machineStatusDialogStockDetailsTitleFontSizeFactor = 0.03; // Stock details title font size as factor of dialog width
  static const double machineStatusDialogStockDetailsSpacingFactor = 0.01; // Spacing before stock details as factor of dialog width
  static const double machineStatusDialogStockItemPaddingFactor = 0.01; // Stock item padding as factor of dialog width
  static const double machineStatusDialogStockItemFontSizeFactor = 0.04; // Stock item font size as factor of dialog width
  static const double machineStatusDialogStockItemBadgePaddingHorizontalFactor = 0.02; // Stock item badge horizontal padding as factor of dialog width
  static const double machineStatusDialogStockItemBadgePaddingVerticalFactor = 0.01; // Stock item badge vertical padding as factor of dialog width
  static const double machineStatusDialogStockItemBadgeFontSizeFactor = 0.04; // Stock item badge font size as factor of dialog width
  static const double machineStatusDialogStockItemBadgeBorderRadiusFactor = 0.01; // Stock item badge border radius as factor of dialog width
  static const double machineStatusDialogCashIconSizeFactor = 0.04; // Cash icon size as factor of dialog width
  static const double machineStatusDialogCashTextFontSizeFactor = 0.04; // Cash text font size as factor of dialog width
  static const double machineStatusDialogCashButtonPaddingFactor = 0.01; // Cash button padding as factor of dialog width
  static const double machineStatusDialogCashButtonBorderRadiusFactor = 0.01; // Cash button border radius as factor of dialog width
  static const double machineStatusDialogCashButtonFontSizeFactor = 0.04; // Cash button font size as factor of dialog width
  
  // ============================================================================
  // MARKET PRODUCT CARD CONSTANTS
  // ============================================================================
  
  /// Product card image sizes (relative to screen)
  static const double productCardImageSizeFactor = 0.048;
  static const double productCardImageFallbackSizeFactor = machineRouteCardIconSizeFactor; // 0.024 - Reuse
  static const double productCardTrendIconSizeFactor = borderRadiusFactorMedium; // 0.016 - Reuse
  
  /// Buy dialog dimensions (relative to screen)
  static const double buyDialogWidthFactor = 0.9; // 90% of screen width
  static const double buyDialogWidthMinFactor = 0.6; // 60% of screen width (min)
  static const double buyDialogWidthMaxFactor = 0.8; // 80% of screen width (max)
  static const double buyDialogHeightFactor = 0.75; // 75% of screen height
  static const double buyDialogHeightMinFactor = 0.5; // 50% of screen height (min)
  static const double buyDialogHeightMaxFactor = 0.85; // 85% of screen height (max)
  static const double buyDialogInsetPaddingFactor = 0.04; // Inset padding relative to screen
  
  /// Buy dialog sizing (relative to dialog width) - No min/max to avoid small screen restrictions
  static const double buyDialogBorderRadiusFactor = 0.03; // Border radius as factor of dialog width
  static const double buyDialogPaddingFactor = 0.03; // Padding as factor of dialog width
  
  /// Buy dialog header - No min/max to avoid small screen restrictions
  static const double buyDialogHeaderPaddingVerticalFactor = 0.5; // Vertical padding as factor of padding
  static const double buyDialogHeaderIconSizeFactor = 0.08; // Icon size as factor of dialog width
  static const double buyDialogHeaderTitleSpacingFactor = 0.5; // Spacing between icon and title as factor of padding
  static const double buyDialogHeaderTitleFontSizeFactor = 0.05; // Title font size as factor of dialog width
  static const double buyDialogCloseButtonSizeFactor = 0.06; // Close button icon size as factor of dialog width
  static const double buyDialogCloseButtonPaddingFactor = 0.3; // Close button padding as factor of padding
  
  /// Buy dialog content - No min/max to avoid small screen restrictions
  static const double buyDialogUnitPriceFontSizeFactor = fontSizeFactorMedium; // 0.035 - Unit price font size (reuse)
  static const double buyDialogContentSpacingFactor = 0.3; // Spacing between title and unit price as factor of padding
  
  /// Buy dialog quantity display - No min/max to avoid small screen restrictions
  static const double buyDialogQuantityContainerPaddingFactor = 0.8; // Container padding as factor of padding
  static const double buyDialogQuantityBorderRadiusFactor = 0.5; // Border radius as factor of borderRadius
  static const double buyDialogQuantityBorderWidthFactor = 0.08; // Border width as factor of padding
  static const double buyDialogQuantityLabelFontSizeFactor = fontSizeFactorMedium; // 0.035 - Label font size (reuse)
  static const double buyDialogQuantityValueFontSizeFactor = fontSizeFactorLarge; // 0.045 - Value font size (reuse)
  
  /// Buy dialog slider
  static const double buyDialogSliderMinValue = 1.0;
  static const double buyDialogSliderSpacingFactor = 0.8; // Spacing after slider as factor of padding
  
  /// Buy dialog increment buttons
  static const List<int> buyDialogIncrementValues = [10, 50, 100]; // Quick increment button values
  static const double buyDialogIncrementButtonSpacingFactor = 0.4; // Spacing between buttons as factor of padding
  
  /// Buy dialog total cost display - No min/max to avoid small screen restrictions
  static const double buyDialogTotalCostContainerPaddingFactor = buyDialogQuantityContainerPaddingFactor; // 0.8 - Reuse
  static const double buyDialogTotalCostBorderRadiusFactor = 0.33; // Border radius as factor of borderRadius
  static const double buyDialogTotalCostLabelFontSizeFactor = fontSizeFactorMedium; // 0.035 - Label font size (reuse)
  static const double buyDialogTotalCostValueFontSizeFactor = fontSizeFactorLarge; // 0.045 - Value font size (reuse)
  
  /// Buy dialog warning messages - No min/max to avoid small screen restrictions
  static const double buyDialogWarningSpacingFactor = 0.3; // Spacing above warning as factor of padding
  static const double buyDialogWarningFontSizeFactor = 0.03; // Warning font size as factor of dialog width
  
  /// Buy dialog action buttons
  static const double buyDialogActionButtonSpacingFactor = 0.5; // Spacing between buttons as factor of padding
  
  /// Small game button (used in buy dialog - dialog-specific sizing) - No min/max to avoid small screen restrictions
  static const double buyDialogButtonPressedMarginFactor = 0.125; // Pressed margin as factor of padding
  static const double buyDialogButtonPaddingHorizontalFactor = 0.8; // Horizontal padding as factor of padding
  static const double buyDialogButtonPaddingVerticalFactor = 0.6; // Vertical padding as factor of padding
  static const double buyDialogButtonBorderRadiusFactor = 0.42; // Border radius as factor of padding
  static const double buyDialogButtonShadowOffsetFactor = buyDialogButtonPressedMarginFactor; // 0.125 - Reuse
  static const double buyDialogButtonBorderWidthFactor = 0.06; // Border width as factor of padding
  static const double buyDialogButtonIconSizeFactor = 0.04; // Icon size as factor of dialog width
  static const double buyDialogButtonIconSpacingFactor = 0.3; // Spacing between icon and text as factor of padding
  static const double buyDialogButtonFontSizeFactor = fontSizeFactorMedium; // 0.035 - Font size (reuse)
  static const double buyDialogButtonLetterSpacing = 0.5; // Letter spacing for button text
  
  /// Machine capacity
  static const double machineMaxCapacity = 50.0;
  static const int machineMaxItemsPerProduct = 20;
  
  /// Machine purchase limits per type
  static const int machineLimitPerType = 2;
  
  /// Fuel cost per unit distance
  static const double fuelCostPerUnit = 0.50;
  
  /// Route efficiency thresholds
  static const double routeEfficiencyGreat = 50.0;
  static const double routeEfficiencyGood = 100.0;
  static const double routeEfficiencyFair = 200.0;
  
  // ============================================================================
  // SIMULATION CONSTANTS
  // ============================================================================
  
  /// Time constants
  /// 1 game day = 5 minutes real time at 10 ticks/second
  /// 5 minutes = 300 seconds = 3000 ticks at 10 ticks/second
  static const int hoursPerDay = 24;
  static const int ticksPerHour = 125; // 3000 ticks per day / 24 hours = 125 ticks per hour
  static const int ticksPerDay = hoursPerDay * ticksPerHour; // 3000
  
  /// Gas/fuel constants
  static const double gasPrice = 0.05; // Cost per unit distance
  
  /// Reputation constants
  static const int emptyMachinePenaltyHours = 4;
  static const int reputationPenaltyPerEmptyHour = 5;
  
  /// Reputation gain from sales
  static const int reputationGainPerSale = 1; // Gain 1 reputation per sale
  
  /// Reputation-based sales bonus
  static const double reputationBonusPer100 = 0.05; // +5% sales rate per 100 reputation (0.05 = 5%)
  static const double maxReputationBonus = 0.50; // Maximum 50% bonus (at 1000 reputation)
  
  /// Item disposal
  static const double disposalCostPerExpiredItem = 0.50;
  
  /// Pathfinding constants
  static const double roadSnapThreshold = 0.1;
  static const double pathfindingHeuristicWeight = 1.0;
  static const double wrongWayPenalty = 10.0;
  
  /// Movement speed
  static const double movementSpeed = 0.1;
  
  // ============================================================================
  // CITY MAP CONSTANTS
  // ============================================================================
  
  /// Grid size
  static const int cityGridSize = 10;
  
  /// Tile spacing factors
  static const double tileSpacingFactor = 0.80;
  static const double horizontalSpacingFactor = 0.70;
  
  /// Building scales
  static const double buildingScale = 0.81;
  static const double schoolScale = 0.77; // School tile scale (same as other small buildings)
  static const double gasStationScale = 0.72;
  static const double parkScale = 0.72;
  static const double houseScale = 0.72;
  static const double warehouseScale = 0.72;
  
  /// Building block sizes
  static const int minBlockSize = 2;
  static const int maxBlockSize = 3;
  
  /// Map padding
  static const double mapSidePadding = 100.0;
  static const double mapTopPadding = 150.0;
  static const double mapBottomPadding = 30.0;
  static const double mapTargetBottomGap = 20.0;
  
  /// Initial zoom
  static const double initialMapZoom = 1.5;
  
  // ============================================================================
  // UI COLORS
  // ============================================================================
  
  /// Primary game colors
  static const Color gameGreen = Color(0xFF4CAF50);
  static const Color surfaceColor = Color(0xFFF5F5F5);
  static const Color grassGreen = Color(0xFF388E3C);
  
  /// Status colors
  static const Color statusGood = Colors.green;
  static const Color statusWarning = Colors.orange;
  static const Color statusDanger = Colors.red;
  
  // ============================================================================
  // DEBOUNCE & TIMING
  // ============================================================================
  
  /// Debounce durations
  static const Duration debounceTap = Duration(milliseconds: 300);
  static const Duration debounceDelay = Duration(milliseconds: 150);
  
  // ============================================================================
  // SAVE/LOAD
  // ============================================================================
  
  static const String saveKey = 'vending_empire_save';
  
  // ============================================================================
  // FLAME GAME CONSTANTS
  // ============================================================================
  
  static const double mapWidth = 1000.0;
  static const double mapHeight = 1000.0;
  
  static const double worldScale = 100.0;
  static const double truckSpeed = 50.0; // Pixels per second
  static const double arrivalThreshold = 2.0;
  static const double blinkSpeed = 2.0; // Blinks per second
}

