import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../controllers/user_controller.dart';
import '../models/user_model.dart';
import '../utils/snackbars.dart';
import '../utils/utils.dart';
import '../widgets/code_form_widget.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final UserController _userController = Get.find<UserController>();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  late String codeUser;
  late String emailUser;

  late TextEditingController nomCtrl;
  late TextEditingController prenomCtrl;
  late TextEditingController telCtrl;
  late TextEditingController adresseCtrl;
  late TextEditingController confirmationCodeCtrl;

  bool inputTelValidation = true;
  DateTime? dateNaissance;

  @override
  void initState() {
    super.initState();

    final user = _userController.currentUser.value;

    nomCtrl = TextEditingController(text: user?.nom ?? "");
    prenomCtrl = TextEditingController(text: user?.prenom ?? "");
    telCtrl = TextEditingController(text: user?.tel ?? "");
    adresseCtrl = TextEditingController(text: user?.adresse ?? "");
    confirmationCodeCtrl = TextEditingController(text: user?.confirmCode ?? "");
    codeUser = user!.matricule!;
    emailUser = user!.email;
    dateNaissance = user?.dateNaissance;
  }

  @override
  void dispose() {
    nomCtrl.dispose();
    prenomCtrl.dispose();
    telCtrl.dispose();
    adresseCtrl.dispose();
    confirmationCodeCtrl.dispose();
    super.dispose();
  }

  // 🔐 Bloque retour si _isLoading = true
  Future<bool> _onWillPop() async {
    if (_isLoading) return false;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Abandonner la modification"),
        content: const Text(
            "Êtes-vous sûr(e) de vouloir quitter ? Toutes les données entrées seront perdues."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Oui, quitter"),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final oldUser = _userController.currentUser.value!;
    final updatedUser = UserModel(
      id: oldUser.id,
      nom: nomCtrl.text.trim(),
      prenom: prenomCtrl.text.trim(),
      email: _userController.email,
      tel: telCtrl.text.trim(),
      adresse: adresseCtrl.text.trim(),
      matricule: codeUser,
      isAdmin: oldUser.isAdmin,
      confirmCode: confirmationCodeCtrl.text.trim(),
      fcmToken: oldUser.fcmToken,
      dateNaissance: dateNaissance,
    );

    await _userController.updateUser(updatedUser);

    setState(() => _isLoading = false);

    showSucessSnackbar(
        context: context, message: "Profil mis à jour avec succès");

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text("Modifier mon profil"),
          leading: _isLoading
              ? null
              : IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) Navigator.of(context).pop();
            },
          ),
        ),

        body: Stack(
          children: [
            _buildForm(),

            // 🔥 Loader plein écran bloquant
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Text(
            "$label : ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildInfoBox(icon: Icons.email, label: "Email", value: emailUser),
            _buildInfoBox(icon: Icons.confirmation_number, label: "Code Stockiste", value: codeUser),

            TextFormField(
              controller: nomCtrl,
              decoration: const InputDecoration(labelText: "Nom"),
              validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
            ),
            TextFormField(
              controller: prenomCtrl,
              decoration: const InputDecoration(labelText: "Prénom"),
              validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
            ),

            const SizedBox(height: 20),

            InternationalPhoneNumberInput(
              onInputChanged: (PhoneNumber number) {},
              onInputValidated: (bool value) {
                setState(() => inputTelValidation = value);
              },
              countries: COUNTRIES_CODES,
              searchBoxDecoration:
              const InputDecoration(labelText: "Recherchez par pays"),
              selectorConfig: const SelectorConfig(
                selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
              ),
              textFieldController: telCtrl,
              inputDecoration: InputDecoration(
                labelText: "Numéro de téléphone",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                errorText: telCtrl.text.isEmpty
                    ? null
                    : !inputTelValidation
                    ? "Numéro invalide"
                    : null,
              ),
            ),

            const SizedBox(height: 5),

            TextFormField(
              controller: adresseCtrl,
              decoration: const InputDecoration(labelText: "Adresse"),
            ),

            const SizedBox(height: 20),


            TextFormField(
              controller: confirmationCodeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration:
              const InputDecoration(labelText: "Code de confirmation"),
            ),

            // Date picker
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => dateNaissance = date);
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: "Date de naissance",
                    hintText: "Choisir votre date de naissance",
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  controller: TextEditingController(
                    text: dateNaissance == null
                        ? ""
                        : dateNaissance!
                        .toLocal()
                        .toString()
                        .split(" ")[0],
                  ),
                  readOnly: true,
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: Text(!_isLoading
                  ? "Mettre à jour"
                  : "Mise à jour en cours..."),
            ),
          ],
        ),
      ),
    );
  }
}
