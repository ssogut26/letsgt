// ignore_for_file: use_build_context_synchronously

import 'dart:math';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:letsgt/app.dart';
import 'package:letsgt/config/routes/routes.dart';
import 'package:letsgt/models/ModelProvider.dart';

abstract class AmplifyAuthService {
  Future<void> signInUser(
    String username,
    String password,
  );
  Future<void> signUpUser(
    String name,
    String email,
    String password,
    String confirmPassword, {
    String? phoneNumber,
  });
  Future<void> confirmSignUp(
    String username,
    String confirmationCode,
  );
  Future<void> confirmResetPassword({
    required String username,
    required String newPassword,
    required String confirmationCode,
  });
  Future<void> resendCode(String email);
  Future<void> signOut();
  Future<void> resetPassword({
    String? username,
  });
  Future<void> saveUserData({
    required String name,
    required String email,
    required String phoneNumber,
  });
}

class MyAuthService implements AmplifyAuthService {
  factory MyAuthService() => _instance;
  MyAuthService._();
  static final MyAuthService _instance = MyAuthService._();

  @override
  Future<void> resendCode(String email) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
    } on AuthException catch (e) {
      safePrint('Error resending code: ${e.message}');
    }
  }

  @override
  Future<void> resetPassword({
    String? username,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final result = await Amplify.Auth.resetPassword(
        username: username ?? '',
      );
      await _handleResetPasswordResult(result, context, ref);
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
      safePrint('Error resetting password: ${e.message}');
    }
  }

  @override
  Future<void> confirmResetPassword({
    required String username,
    required String newPassword,
    required String confirmationCode,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final result = await Amplify.Auth.confirmResetPassword(
        username: username,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      await ref?.read(appRouterProvider).replace(const SignInRoute());
      safePrint('Password reset complete: ${result.isPasswordReset}');
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
      safePrint('Error confirming reset password: ${e.message}');
    }
  }

  @override
  Future<void> signInUser(
    String username,
    String password, {
    WidgetRef? ref,
    BuildContext? context,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: username,
        password: password,
      );
      await _handleSignInResult(
        result,
        ref,
        context,
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
      if (e.message == 'A user is already signed in.') {
        await ref?.read(appRouterProvider).replace(const HomeRoute());
      }
      safePrint('Error signing in: ${e.message}');
    }
  }

  Future<void> resendSingUpCode({String? username}) async {
    final resendResult = await Amplify.Auth.resendSignUpCode(
      username: username ?? '',
    );
    _handleCodeDelivery(resendResult.codeDeliveryDetails);
  }

  Future<void> _handleSignInResult(
    SignInResult result,
    WidgetRef? ref,
    BuildContext? context,
  ) async {
    switch (result.nextStep.signInStep) {
      case AuthSignInStep.confirmSignInWithSmsMfaCode:
        final codeDeliveryDetails = result.nextStep.codeDeliveryDetails!;
        _handleCodeDelivery(codeDeliveryDetails);
      case AuthSignInStep.confirmSignInWithNewPassword:
        safePrint('Enter a new password to continue signing in');
      case AuthSignInStep.confirmSignInWithCustomChallenge:
        final parameters = result.nextStep.additionalInfo;
        final prompt = parameters['prompt']!;
        safePrint(prompt);
      // I will add later
      case AuthSignInStep.resetPassword:
        await resetPassword();
      case AuthSignInStep.confirmSignUp:
        // Resend the sign up code to the registered device.
        await resendSingUpCode();
      case AuthSignInStep.done:
        try {
          ScaffoldMessenger.of(context!).showSnackBar(
            const SnackBar(
              content: Text('Sign in is complete'),
            ),
          );
          await ref?.read(appRouterProvider).replace(const HomeRoute());
        } on AuthException catch (e) {
          ScaffoldMessenger.of(context!).showSnackBar(
            SnackBar(
              content: Text(e.message),
            ),
          );
        }

        safePrint('Sign in is complete');
    }
  }

  Future<void> _handleResetPasswordResult(
    ResetPasswordResult result,
    BuildContext? context,
    WidgetRef? ref,
  ) async {
    switch (result.nextStep.updateStep) {
      case AuthResetPasswordStep.confirmResetPasswordWithCode:
        await ref?.read(appRouterProvider).push(
              const ConfirmResetPasswordRoute(),
            );
        final codeDeliveryDetails = result.nextStep.codeDeliveryDetails!;
        _handleCodeDelivery(codeDeliveryDetails);
      case AuthResetPasswordStep.done:
        await ref?.read(appRouterProvider).replace(const SignInRoute());
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(
            content: Text('Successfully reset password'),
          ),
        );
        safePrint('Successfully reset password');
    }
  }

  void _handleCodeDelivery(AuthCodeDeliveryDetails codeDeliveryDetails) {
    safePrint(
      'A confirmation code has been sent to ${codeDeliveryDetails.destination}. '
      'Please check your ${codeDeliveryDetails.deliveryMedium.name} for the code.',
    );
  }

  @override
  Future<void> signOut({
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      await Amplify.Auth.signOut();
      await ref?.read(appRouterProvider).replace(const SignInRoute());
      ScaffoldMessenger.of(context!).showSnackBar(
        const SnackBar(
          content: Text('Sign out is complete'),
        ),
      );
    } on AuthException catch (e) {
      safePrint('Error signing out: ${e.message}');
    }
  }

  @override
  Future<void> signUpUser(
    String name,
    String email,
    String password,
    String confirmPassword, {
    String? phoneNumber,
    WidgetRef? ref,
    BuildContext? context,
  }) async {
    try {
      final userAttributes = {
        AuthUserAttributeKey.email: email,
        if (phoneNumber != null) AuthUserAttributeKey.phoneNumber: phoneNumber,
        AuthUserAttributeKey.name: name,
      };
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: userAttributes,
        ),
      );
      await _handleSignUpResult(result, ref, context).whenComplete(
        () async => saveUserData(
          name: name,
          email: email,
          phoneNumber: phoneNumber ?? '',
        ),
      );
    } on AuthException catch (e) {
      safePrint('Error signing up user: ${e.message}');
    }
  }

  Future<void> _handleSignUpResult(
    SignUpResult result,
    WidgetRef? ref,
    BuildContext? context,
  ) async {
    switch (result.nextStep.signUpStep) {
      case AuthSignUpStep.confirmSignUp:
        await ref?.read(appRouterProvider).push(const SignUpConfirmRoute());
        final codeDeliveryDetails = result.nextStep.codeDeliveryDetails!;
        _handleCodeDelivery(codeDeliveryDetails);
      case AuthSignUpStep.done:
        try {
          await ref?.read(appRouterProvider).push(const SignInRoute());
        } on AuthException catch (e) {
          ScaffoldMessenger.of(context!).showSnackBar(
            SnackBar(
              content: Text(e.message),
            ),
          );
        }
        safePrint('Sign up is complete');
    }
  }

  @override
  Future<void> confirmSignUp(
    String username,
    String confirmationCode, {
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: username,
        confirmationCode: confirmationCode,
      );
      // Check if further confirmations are needed or if
      // the sign up is complete.
      await _handleSignUpResult(result, ref, context);
    } on AuthException catch (e) {
      safePrint('Error confirming user: ${e.message}');
    }
  }

  Future<void> confirmUser({
    required String username,
    required String confirmationCode,
    WidgetRef? ref,
    BuildContext? context,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: username,
        confirmationCode: confirmationCode,
      );
      // Check if further confirmations are needed or if
      // the sign up is complete.
      await _handleSignUpResult(result, ref, context);
    } on AuthException catch (e) {
      safePrint('Error confirming user: ${e.message}');
    }
  }

  @override
  Future<void> saveUserData({
    required String name,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      final userData = UserModel(
        userName: name,
        id: '1',
        location: '',
        userStatus: 'Active',
      );
      final request = ModelMutations.create(
        userData,
      );

      final response = await Amplify.API.mutate(request: request).response;
      final createdUserData = response.data;
      if (createdUserData != null) {
        safePrint('User data saved successfully');
      } else {
        safePrint('User data not saved');
      }
    } on ApiException catch (e) {
      safePrint('Error saving user data: ${e.message}');
    }
  }

  Future<void> createActivity({
    required String activityName,
    required String activityDescription,
    required TemporalDateTime selectedDate,
    required String selectedLocation,
    String? createdBy,
  }) async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final userName = attributes
          .firstWhere((element) => element.userAttributeKey.key == 'name')
          .value;
      final randomId = Random().nextInt(10000);
      final activityData = ActivityModel(
        id: randomId.toString(),
        activityDescription: activityDescription,
        activityName: activityName,
        selectedDate: selectedDate,
        selectedLocation: selectedLocation,
        participants: const ['Selcuk'],
        createdBy: userName,
      );
      final request = ModelMutations.create(
        activityData,
      );

      final response = await Amplify.API.mutate(request: request).response;

      final createdActivityData = response.data;

      if (createdActivityData == null) {
        safePrint('errors: ${response.errors}');
        return;
      }
      safePrint('Mutation result: ${createdActivityData.activityName}');
    } on ApiException catch (e) {
      safePrint('Error creating activity: ${e.message}');
    }
  }

  Future<List<ActivityModel?>> fetchActivities() async {
    try {
      final request = ModelQueries.list(ActivityModel.classType);
      final response = await Amplify.API.query(request: request).response;

      final activities = response.data?.items;
      if (activities == null) {
        safePrint('errors: ${response.errors}');
        return const [];
      }
      activities.sort(
        (a, b) =>
            a!.createdAt?.compareTo(
              b!.createdAt!,
            ) ??
            0,
      );
      return activities;
    } on ApiException catch (e) {
      safePrint('Query failed: $e');
      return const [];
    }
  }

  Future<ActivityModel?> getActivityDetails(
    ActivityModel queriedActivity,
  ) async {
    try {
      final request = ModelQueries.get(
        ActivityModel.classType,
        queriedActivity.modelIdentifier,
      );

      final response = await Amplify.API.query(request: request).response;

      final activity = response.data;
      if (activity == null) {
        safePrint('errors: ${response.errors}');
      }
      return activity;
    } on ApiException catch (e) {
      safePrint('Query failed: $e');
      return null;
    }
  }
}
