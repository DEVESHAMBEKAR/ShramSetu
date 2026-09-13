class MockAuthService {
  /// Simulates sending an OTP to the given phone number.
  Future<void> sendOtp(String phoneNumber) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // In a real app, this would call Supabase to send the OTP.
    if (phoneNumber.isEmpty || phoneNumber.length < 10) {
      throw Exception('Invalid phone number');
    }
  }

  /// Simulates verifying the OTP.
  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // In a real app, this would call Supabase auth.verifyOTP.
    // For mock purposes, '123456' is the valid mock OTP.
    if (otp == '123456') {
      return true;
    }
    return false;
  }
}
