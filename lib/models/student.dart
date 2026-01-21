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
  final String? nomMere;
  final String classe;
  final String annee;
  final String statut;
  final String photo;

  Student({
    required this.id,
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    required this.lieuNaissance,
    required this.sexe,
    this.nomPere,
    this.nomMere,
    required this.classe,
    this.annee = '',
    required this.statut,
    this.photo = '',
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
      nomMere: map['nom_mere']?.toString(),
      classe: map['classe_nom']?.toString() ?? '',
      annee: map['annee']?.toString() ?? '',
      statut: map['statut']?.toString() ?? 'inscrit',
      photo: map['photo']?.toString() ?? '',
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
      'nom_mere': nomMere,
      'classe': classe,
      'annee': annee,
      'statut': statut,
      'photo': photo,
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
    String? nomMere,
    String? classe,
    String? annee,
    String? statut,
    String? photo,
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
      nomMere: nomMere ?? this.nomMere,
      classe: classe ?? this.classe,
      annee: annee ?? this.annee,
      statut: statut ?? this.statut,
      photo: photo ?? this.photo,
    );
  }

  // Getter pour le nom complet
  String get fullName => '$nom $prenom';

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
