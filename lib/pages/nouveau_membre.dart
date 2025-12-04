import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/django_api_pays.dart';
import '../models/custumer_account.dart';
import '../models/ville_api.dart';
import '../services/cloudinary_service.dart';
import '../services/customer_account_service.dart';
import '../services/image_service.dart';
import '../utils/snackbars.dart';
import '../utils/utils.dart';
import '../widgets/code_form_widget.dart';

class AddAccountPage extends StatefulWidget {

  final CustomerAccount? account; // pour l’édition
  const AddAccountPage({super.key, this.account});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = CustomerAccountService();

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _adressCtrl = TextEditingController();
  final _sponsorCtrl = TextEditingController();
  final _placementCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();

  DateTime? _birthDate;

  // Dropdown values
  String? _idType;
  String? _gender;
  String? _country = "GN";
  VillesAPiModel? _city;
  VillesAPiModel? _commune;

  List<VillesAPiModel> _villes = [];
  List<VillesAPiModel> _communes = [];

  bool _loadingCities = false;
  bool _loadingCommunes = false;
  bool inputTelValidation = false;
  bool _isloading = false;

  File? _imageFile;              // nouvelle image choisie
  bool _removeExistingImage = false; // indique si on veut supprimer l’image actuelle


  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    // Remplir les champs textes directement pour l'utilisateur
    if (widget.account != null) {
      final acc = widget.account!;
      _firstNameCtrl.text = acc.firstName;
      _lastNameCtrl.text = acc.lastName;
      _idType = acc.idType;
      _idNumberCtrl.text = acc.idNumber!;
      _birthDate = acc.birthDate;
      _country = acc.country;
      _matriculeCtrl.text = acc.matricule ?? '';
      _adressCtrl.text = acc.neighborhood ?? '';
      _phoneCtrl.text = acc.phone!;
      _gender = acc.gender;
      _sponsorCtrl.text = acc.sponsorCode ?? '';
      _placementCtrl.text = acc.placementCode ?? '';

    }

    // Charger les villes de façon asynchrone
    _loadCitiesAndSelect();
  }

  Future<void> _selectImage() async {
    File? image = await ImageService.pickGalleryImage();
    if (image != null) {
      setState(() => _imageFile = image);
    }
  }

  void _cancelImage() => setState(() => _imageFile = null);


  Future<bool> _onWillPop() async {
    bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.account != null
            ? "Abandonner la modification du membre"
            : "Abandonner l'ajout du membre"),
        content: const Text(
            "Êtes-vous sûr(e) de vouloir quitter ? Toutes les données entrées seront perdues."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
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

// Charge villes et sélectionne ville + commune si existant
  Future<void> _loadCitiesAndSelect() async {
    setState(() => _loadingCities = true);

    try {
      _villes = await fetchCities(_country!);
    } catch (e) {
      print("Erreur chargement villes : $e");
    }
    setState(() => _loadingCities = false);

    // Sélectionner la ville si édit
    if (widget.account != null && widget.account!.province != null) {
      final acc = widget.account!;
      _city = _villes.firstWhere(
            (v) => v.nom.toLowerCase() == acc.province!.toLowerCase(),
        orElse: () => _villes.isNotEmpty
            ? _villes.first
            : VillesAPiModel(nom: acc.province!, villeID: 0),
      );

      // Charger les communes pour cette ville
      if (_city != null) {
        setState(() => _loadingCommunes = true);
        try {
          _communes = await fetchChildren(_country!, _city!.villeID);
        } catch (e) {
          print("Erreur chargement communes : $e");
        }
        setState(() => _loadingCommunes = false);

        // Sélectionner la commune si édit
        if (acc.city != null) {
          _commune = _communes.firstWhere(
                (c) => c.nom.toLowerCase() == acc.city!.toLowerCase(),
            orElse: () =>
            _communes.isNotEmpty ? _communes.first : VillesAPiModel(nom: acc.city!, villeID: 0),
          );
        }
      }
    }
  }



  void _loadCities() async {
    setState(() => _loadingCities = true);
    try {
      _villes = await fetchCities(_country!);
    } catch (e) {
      print(e);
    }
    setState(() => _loadingCities = false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.account != null ? "Modification membre" : "Nouveau membre"), // couleur héritée
          backgroundColor: Colors.blueGrey,
          iconTheme: const IconThemeData(color: Colors.white), // toutes les icônes
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), // titre
        ),

        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(_firstNameCtrl, "Prénom"),
                _buildTextField(_lastNameCtrl, "Nom"),


                SizedBox(height: 20,),

                CodeFormField(
                  controller: _sponsorCtrl,
                  label: "Code Sponsor",
                ),
                CodeFormField(
                  controller: _placementCtrl,
                  label: "Code Placement",
                ),


                SizedBox(height: 20,),

                _buildDropdown(
                  label: "Type de carte",
                  value: _idType,
                  items: const [
                    DropdownMenuItem(
                        value: "carte_identite", child: Text("Carte d'identité")),
                    DropdownMenuItem(value: "passport", child: Text("Passeport")),
                    DropdownMenuItem(
                        value: "social_security", child: Text("Social Security")),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _idType = v;
                      _idNumberCtrl.clear();
                    });
                  },
                ),
                _buildIdNumberField(),

                _buildDatePickerField(),
                SizedBox(height: 15,),
                _buildDropdown(
                  label: "Pays",
                  value: _country,
                  items: countries.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) async {
                    _country = v;
                    _city = null;
                    _commune = null;
                    setState(() => _loadingCities = true);
                    _villes = await fetchCities(v!);
                    setState(() => _loadingCities = false);
                  },
                ),
                const SizedBox(height: 10),
                _buildCityDropdown(),
                const SizedBox(height: 10),
                _buildCommuneDropdown(),
                const SizedBox(height: 10),
                _buildTextField(_adressCtrl, "Domicile"),
                const SizedBox(height: 10),
                _buildPhoneField(),
                _buildDropdown(
                  label: "Genre",
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: "masculin", child: Text("Masculin")),
                    DropdownMenuItem(value: "feminin", child: Text("Féminin")),
                  ],
                  onChanged: (v) => _gender = v,
                ),
                (_imageFile != null || widget.account != null) ?
                CodeFormField(
                  controller: _matriculeCtrl,
                  label: "Code du membre",
                  requis: true,
                ) :
                    SizedBox(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        // si une image est supprimée, mais qu’on en sélectionne une autre → annuler la suppression
                        if (_removeExistingImage) {
                          setState(() => _removeExistingImage = false);
                        }
                        await _selectImage();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _imageFile != null
                            ? Image.file(_imageFile!, width: 230, height: 260, fit: BoxFit.cover)

                        // ► CAS : image supprimée volontairement
                            : (widget.account?.imageUrl != null &&
                            widget.account!.imageUrl!.isNotEmpty &&
                            !_removeExistingImage)
                            ? CachedNetworkImage(
                          imageUrl: widget.account!.imageUrl!,
                          placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                          width: 230,
                          height: 260,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 200,
                          height: 260,
                          decoration:
                          BoxDecoration(border: Border.all(color: Colors.grey)),
                          child: const Icon(Icons.add_a_photo, color: Colors.grey),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // BOUTON ACTION IMAGE
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_imageFile != null) {
                            // → on annule la sélection
                            _imageFile = null;
                          } else if (!_removeExistingImage &&
                              widget.account?.imageUrl != null) {
                            // → supprimer l’ancienne image
                            _removeExistingImage = true;
                          } else {
                            // → réactiver l’ancienne image (undo)
                            _removeExistingImage = false;
                          }
                        });
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.redAccent,
                        child: Icon(
                          _imageFile != null
                              ? Icons.close              // annuler la nouvelle image
                              : (_removeExistingImage
                              ? Icons.undo           // restaurer l'ancienne
                              : Icons.delete),       // supprimer ancienne
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                )
,
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blueGrey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isloading ? null : _submit,
                    icon: const Icon(Icons.save, color: Colors.white,),
                    label:
                        Text(_isloading ? widget.account != null ? "Modification en cours..." : "Enregistrement en cours..." : widget.account != null ? "Modifier" : "Enregistrer", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => v == null || v.isEmpty ? "$label requis" : null,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem> items,
    required Function(dynamic) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<dynamic>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        value: value,
        items: items,
        onChanged: onChanged,
        validator: (v) => v == null ? "$label requis" : null,
      ),
    );
  }

  Widget _buildIdNumberField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: _idNumberCtrl,
        decoration: InputDecoration(
          labelText: "Numéro de carte",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        keyboardType: TextInputType.text,
        maxLength: _idType == "carte_identite"
            ? 16
            : _idType == "passport"
                ? 9
                : 20,
        inputFormatters: [
          LengthLimitingTextInputFormatter(
            _idType == "carte_identite"
                ? 16
                : _idType == "passport"
                    ? 9
                    : 20,
          ),
        ],
        onChanged: (v) => setState(() {}),
        validator: (v) {
          if (v == null || v.isEmpty) return "Numéro requis";
          final len = v.length;
          switch (_idType) {
            case "carte_identite":
              if (len != 16) return "Le numéro CNI doit contenir 16 caractères";
              break;
            case "passport":
              if (len != 9)
                return "Le numéro de passeport doit contenir 9 caractères";
              break;
            case "social_security":
              if (len < 9 || len > 20)
                return "Numéro sécurité sociale entre 9 et 20 caractères";
              break;
            default:
              return "Choisissez d'abord un type de carte";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePickerField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            setState(() => _birthDate = date);
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
              text: _birthDate == null
                  ? ''
                  : _birthDate!.toLocal().toString().split(' ')[0],
            ),
            readOnly: true,
          ),
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VillesAPiModel>(
          isExpanded: true,
          value: _villes.contains(_city) ? _city : null,
          hint: Text(
            "Sélectionner la ville",
            style:
                TextStyle(color: _villes.isEmpty ? Colors.grey : Colors.black),
          ),
          items: _villes
              .map((city) => DropdownMenuItem(
                    value: city,
                    child: Text(city.nom),
                  ))
              .toList(),
          onChanged: (value) async {
            _city = value;
            _commune = null;
            setState(() => _loadingCommunes = true);
            _communes = await fetchChildren(_country!, value!.villeID);
            setState(() => _loadingCommunes = false);
          },
        ),
      ),
    );
  }

  Widget _buildCommuneDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VillesAPiModel>(
          isExpanded: true,
          value: _communes.contains(_commune) ? _commune : null,
          hint: Text(
            "Sélectionner la commune",
            style: TextStyle(
                color: _communes.isEmpty ? Colors.grey : Colors.black),
          ),
          items: _communes
              .map((commune) => DropdownMenuItem(
                    value: commune,
                    child: Text(commune.nom),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _commune = value),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child:             InternationalPhoneNumberInput(
        onInputChanged: (PhoneNumber number) {
          // Tu peux garder vide ou logger si tu veux
        },
        onInputValidated: (bool value) {
          setState(() => inputTelValidation = value); // ✅ vrai ou faux
        },
        countries: COUNTRIES_CODES,
        searchBoxDecoration: const InputDecoration(labelText: "Recherchez par pays"),
        selectorConfig: const SelectorConfig(
          selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
        ),
        textFieldController: _phoneCtrl,
        inputDecoration: InputDecoration(
          labelText: "Numéro de téléphone",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          errorText: _phoneCtrl.text.isEmpty
              ? null
              : !inputTelValidation
              ? "Numéro invalide"
              : null,
        ),
        errorMessage: "Numéro invalide",
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_commune == null || _city == null) {
      return showErrorSnackbar(
          context: context, message: "Indiquez la ville et la commune");
    }

    setState(() => _isloading = true);

    String? imageUrl = widget.account?.imageUrl; // valeur de départ

    try {
      // 1️⃣ SUPPRESSION DE L'ANCIENNE IMAGE
      if (_removeExistingImage && widget.account?.imageUrl != null) {
        await CloudinaryService()
            .deleteCloudinaryResource(widget.account!.imageUrl!);
        imageUrl = null; // DB doit recevoir null
      }

      // 2️⃣ UPLOAD D'UNE NOUVELLE IMAGE
      if (_imageFile != null) {
        // si une image existait → la supprimer d’abord
        if (widget.account?.imageUrl != null && !_removeExistingImage) {
          await CloudinaryService()
              .deleteCloudinaryResource(widget.account!.imageUrl!);
        }

        imageUrl = await CloudinaryService.uploadImageToCloudinary(
          _imageFile!,
          "preset_infos_compte",
        );
      }

      // 3️⃣ CREATION / MISE À JOUR DU COMPTE
      final userId = supabase.auth.currentUser!.id;

      final account = CustomerAccount(
        id: widget.account?.id,
        user_id: userId,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        idType: _idType!,
        idNumber: _idNumberCtrl.text.trim(),
        birthDate: _birthDate!,
        country: _country!,
        province: _city?.nom,
        city: _commune?.nom,
        neighborhood: _adressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        gender: _gender!,
        sponsorCode: _sponsorCtrl.text.trim(),
        placementCode: _placementCtrl.text.trim(),
        matricule: _matriculeCtrl.text.trim(),
        imageUrl: imageUrl,
      );

      if (widget.account == null) {
        await _service.createAccount(account);
        showSucessSnackbar(context: context, message: "✅ Compte créé avec succès");
      } else {
        await _service.updateAccount(account);
        showSucessSnackbar(context: context, message: "✅ Compte mis à jour avec succès");
      }

      if (mounted) Navigator.pop(context, account);

    } catch (e) {
      showErrorSnackbar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isloading = false);
    }
  }


}
