import 'package:flutter/material.dart';

class Student {
  final String id;
  final String matricule;
  final String nom;
  final String prenom;
  final String dateNaissance;
  final String lieuNaissance;
  final String sexe;
  final String? nomPere;
  final String? prenomPere;
  final String? nomMere;
  final String? prenomMere;
  final String classe;
  final String annee;
  final String statut;
  final String photo;
  final String? personneAPrevenir;
  final String? contactUrgence;

  Student({
    required this.id,
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    required this.lieuNaissance,
    required this.sexe,
    this.nomPere,
    this.prenomPere,
    this.nomMere,
    this.prenomMere,
    required this.classe,
    this.annee = '',
    required this.statut,
    this.photo = '',
    this.personneAPrevenir,
    this.contactUrgence,
  });

  // Constructeur depuis Map (pour SQLite)
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id']?.toString() ?? '',
      matricule: map['matricule']?.toString() ?? '',
      nom: map['nom']?.toString() ?? '',
      prenom: map['prenom']?.toString() ?? '',
      dateNaissance: map['date_naissance']?.toString() ?? '',
      lieuNaissance: map['lieu_naissance']?.toString() ?? '',
      sexe: map['sexe']?.toString() ?? 'M',
      nomPere: map['nom_pere']?.toString(),
      prenomPere: map['prenom_pere']?.toString(),
      nomMere: map['nom_mere']?.toString(),
      prenomMere: map['prenom_mere']?.toString(),
      classe: map['classe_nom']?.toString() ?? '',
      annee: map['annee']?.toString() ?? '',
      statut: map['statut']?.toString() ?? 'inscrit',
      photo: map['photo']?.toString() ?? '',
      personneAPrevenir: map['personne_a_prevenir']?.toString(),
      contactUrgence: map['contact_urgence']?.toString(),
    );
  }

  // Convertir en Map (pour SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'date_naissance': dateNaissance,
      'lieu_naissance': lieuNaissance,
      'sexe': sexe,
      'nom_pere': nomPere,
      'prenom_pere': prenomPere,
      'nom_mere': nomMere,
      'prenom_mere': prenomMere,
      'classe': classe,
      'annee': annee,
      'statut': statut,
      'photo': photo,
      'personne_a_prevenir': personneAPrevenir,
      'contact_urgence': contactUrgence,
    };
  }

  // Constructeur de copie avec modifications
  Student copyWith({
    String? id,
    String? matricule,
    String? nom,
    String? prenom,
    String? dateNaissance,
    String? lieuNaissance,
    String? sexe,
    String? nomPere,
    String? prenomPere,
    String? nomMere,
    String? prenomMere,
    String? classe,
    String? annee,
    String? statut,
    String? photo,
    String? personneAPrevenir,
    String? contactUrgence,
  }) {
    return Student(
      id: id ?? this.id,
      matricule: matricule ?? this.matricule,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      lieuNaissance: lieuNaissance ?? this.lieuNaissance,
      sexe: sexe ?? this.sexe,
      nomPere: nomPere ?? this.nomPere,
      prenomPere: prenomPere ?? this.prenomPere,
      nomMere: nomMere ?? this.nomMere,
      prenomMere: prenomMere ?? this.prenomMere,
      classe: classe ?? this.classe,
      annee: annee ?? this.annee,
      statut: statut ?? this.statut,
      photo: photo ?? this.photo,
      personneAPrevenir: personneAPrevenir ?? this.personneAPrevenir,
      contactUrgence: contactUrgence ?? this.contactUrgence,
    );
  }

  // Getter pour le nom complet
  String get fullName => '$nom $prenom';

  String get fatherFullName => '${prenomPere ?? ''} ${nomPere ?? ''}'.trim();
  String get motherFullName => '${prenomMere ?? ''} ${nomMere ?? ''}'.trim();

  String get parentName {
    if (fatherFullName.isNotEmpty) return fatherFullName;
    if (motherFullName.isNotEmpty) return motherFullName;
    return 'Non défini';
  }

  // Getter pour l'affichage du sexe
  String get sexeDisplay => sexe == 'M' ? 'Masculin' : 'Féminin';

  // Getter pour l'icône du sexe
  IconData get sexeIcon => sexe == 'M' ? Icons.man : Icons.woman;

  // Getter pour la couleur du sexe
  Color get sexeColor => sexe == 'M' ? Colors.blue : Colors.pink;

  // Getter pour le statut affiché
  String get statutDisplay {
    switch (statut.toLowerCase()) {
      case 'inscrit':
        return 'Inscrit';
      case 'reinscrit':
        return 'Réinscrit';
      case 'sorti':
        return 'Sorti';
      default:
        return statut;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Student{id: $id, matricule: $matricule, nom: $nom, prenom: $prenom, classe: $classe}';
  }
}
