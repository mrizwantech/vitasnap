// App-wide string constants for UI text.
//
// Centralizes all user-facing strings for easier maintenance,
// localization, and consistency across the app.

class AppStrings {
  AppStrings._();

  // ==================== App Info ====================
  static const appName = 'VitaSnap';
  static const appTagline = 'Scan. Know. Thrive.';

  // ==================== Common ====================
  static const hello = 'Hello';
  static const cancel = 'Cancel';
  static const save = 'Save';
  static const ok = 'OK';
  static const error = 'Error';
  static const success = 'Success';
  static const loading = 'Loading...';
  static const comingSoon = 'Coming soon!';
  static const retry = 'Retry';
  static const close = 'Close';
  static const search = 'Search';
  static const submit = 'Submit';
  static const done = 'Done';
  static const back = 'Back';
  static const next = 'Next';
  static const yes = 'Yes';
  static const no = 'No';
  static const defaultUserName = 'there';
  static const user = 'User';

  // ==================== Home Dashboard ====================
  static const recentScans = 'Recent Scans';
  static const noScansYet = 'No scans yet. Tap the button to scan a product.';
  static const weeklyStats = 'Weekly Stats';
  static const averageScoreThisWeek = 'Average score this week';
  static const scanIt = 'Scan it';
  static const searchByNameOrBarcode = 'Search by name or barcode';
  static const editName = 'Edit name';
  static const yourName = 'Your name';

  // ==================== Navigation ====================
  static const home = 'Home';
  static const stats = 'Stats';
  static const feed = 'Feed';
  static const profile = 'Profile';

  // ==================== Auth - Login ====================
  static const signIn = 'Sign In';
  static const signInWithGoogle = 'Continue with Google';
  static const signInWithPhone = 'Continue with Phone';
  static const signInFailed = 'Sign in failed';
  static const googleSignInFailed = 'Google sign in failed';
  static const forgotPassword = 'Forgot Password?';
  static const dontHaveAccount = "Don't have an account? ";
  static const signUp = 'Sign Up';
  static const emailLabel = 'Email';
  static const passwordLabel = 'Password';
  static const pleaseEnterEmail = 'Please enter your email';
  static const pleaseEnterValidEmail = 'Please enter a valid email';
  static const pleaseEnterPassword = 'Please enter your password';
  static const passwordMinLength = 'Password must be at least 6 characters';
  static const pleaseEnterEmailFirst = 'Please enter your email first';
  static const passwordResetEmailSent = 'Password reset email sent!';
  static const failedToSendResetEmail = 'Failed to send reset email';

  // ==================== Auth - Sign Up ====================
  static const createAccount = 'Create Account';
  static const signUpToGetStarted = 'Sign up to get started';
  static const fullNameLabel = 'Full Name';
  static const confirmPasswordLabel = 'Confirm Password';
  static const pleaseEnterName = 'Please enter your name';
  static const passwordsDontMatch = 'Passwords do not match';
  static const signUpFailed = 'Sign up failed';
  static const alreadyHaveAccount = 'Already have an account? ';

  // ==================== Auth - Phone ====================
  static const phoneSignIn = 'Phone Sign In';
  static const enterPhoneNumber = 'Enter your phone number to continue';
  static const phoneNumberLabel = 'Phone Number';
  static const pleaseEnterPhoneNumber = 'Please enter your phone number';
  static const sendCode = 'Send Code';
  static const verificationCodeSent = 'Verification code sent!';
  static const enterVerificationCode = 'Enter the 6-digit code sent to your phone';
  static const verifyCode = 'Verify Code';
  static const resendCode = 'Resend Code';
  static const verificationFailed = 'Verification failed';

  // ==================== Profile ====================
  static const editProfile = 'Edit Profile';
  static const notifications = 'Notifications';
  static const dietaryPreferences = 'Dietary Preferences';
  static const helpAndSupport = 'Help & Support';
  static const privacyPolicy = 'Privacy Policy';
  static const signOut = 'Sign Out';
  static const signOutConfirmTitle = 'Sign Out';
  static const signOutConfirmMessage = 'Are you sure you want to sign out?';

  // ==================== Settings ====================
  static const settings = 'Settings';
  static const theme = 'Theme';
  static const themeLight = 'Light';
  static const themeDark = 'Dark';
  static const themeSystem = 'System';
  static const clearHistory = 'Clear History';
  static const clearHistoryConfirmTitle = 'Clear All History?';
  static const clearHistoryConfirmMessage = 'This will permanently delete all your scanned products and you will be starting over from scratch. This action cannot be undone.';
  static const historyCleared = 'All scan history has been cleared';
  static const noHistoryToClear = 'No scan history to clear';
  static const dataAndPrivacy = 'Data & Privacy';
  static const about = 'About';

  // ==================== Product ====================
  static const productNotFound = 'Product Not Found';
  static const unknownBrand = 'Unknown brand';
  static const unknownProduct = 'Unknown Product';
  static const addToHistory = 'Add to History';
  static const share = 'Share';
  static const nutritionFacts = 'Nutrition Facts';
  static const ingredients = 'Ingredients';
  static const allergens = 'Allergens';
  static const noIngredientsAvailable = 'No ingredients information available';
  static const noAllergensDetected = 'No allergens detected';
  static const perServing = 'Per serving';
  static const per100g = 'Per 100g';
  static const calories = 'Calories';
  static const protein = 'Protein';
  static const carbs = 'Carbs';
  static const fat = 'Fat';
  static const sugar = 'Sugar';
  static const fiber = 'Fiber';
  static const sodium = 'Sodium';
  static const saturatedFat = 'Saturated Fat';

  // ==================== Product Not Found ====================
  static const couldntFindProduct = "We couldn't find a product with barcode:";
  static const productNotInDatabase = 'This product may not be in our database yet.\nWould you like to contribute by adding it?';
  static const addProduct = 'Add Product';
  static const addProductFeatureComingSoon = 'Add product feature coming soon!';
  static const scanAnotherProduct = 'Scan Another Product';
  static const goBack = 'Go Back';

  // ==================== Search ====================
  static const searchResults = 'Search Results';
  static const noProductsFound = 'No products found';
  static String noProductsFoundFor(String query) => 'No products found for "$query"';
  static String searchError(String error) => 'Search error: $error';

  // ==================== Grades ====================
  static const gradeExcellent = 'Excellent nutritional quality';
  static const gradeGood = 'Good nutritional quality';
  static const gradeFair = 'Fair nutritional quality';
  static const gradePoor = 'Poor nutritional quality';
  static const gradeVeryPoor = 'Very poor nutritional quality';
  static const gradeNotRated = 'Not yet rated';

  // ==================== Dietary Labels ====================
  static const halal = 'Halal';
  static const kosher = 'Kosher';
  static const vegan = 'Vegan';
  static const vegetarian = 'Vegetarian';
  static const noDietaryInfo = 'No dietary info';

  // ==================== Scan ====================
  static const scanBarcode = 'Scan Barcode';
  static const pointCameraAtBarcode = 'Point your camera at a product barcode';
  static const orEnterManually = 'Or enter barcode manually';
  static const enterBarcode = 'Enter Barcode';
  static const invalidBarcode = 'Invalid barcode format';

  // ==================== Errors ====================
  static const somethingWentWrong = 'Something went wrong';
  static const networkError = 'Network error. Please check your connection.';
  static const tryAgain = 'Please try again';
  static const unexpectedError = 'An unexpected error occurred';

  // ==================== Plurals ====================
  static String scansCount(int count) => '$count scan${count == 1 ? '' : 's'}';
}
