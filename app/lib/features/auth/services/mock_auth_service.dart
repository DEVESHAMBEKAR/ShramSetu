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
    
    // For mock/test purposes, '123456', '111111', or any repeated-digit OTP is valid.
    if (otp == '123456' || otp == '111111' || RegExp(r'^(\d)\1{5}$').hasMatch(otp)) {
      return true;
    }
    return false;
  }
}
