import 'package:flutter/material.dart';

class RestaurantLogin extends StatefulWidget {
  const RestaurantLogin({Key? key}) : super(key: key);

  @override
  State<RestaurantLogin> createState() => _RestaurantLoginState();
}

class _RestaurantLoginState extends State<RestaurantLogin> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void loginRestaurant() {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // هنا تحقق تسجيل الدخول من الفيربيز
    // مثال:
    // FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);

    Navigator.pushReplacementNamed(context, '/restaurantHome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 330,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "تسجيل دخول المطعم",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "البريد الإلكتروني",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "كلمة المرور",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: loginRestaurant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: const Text("تسجيل الدخول"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}