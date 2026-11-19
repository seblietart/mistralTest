# Mon Budget

Application iPhone (SwiftUI + SwiftData, iOS 17+) de suivi de budget mensuel.

## Fonctionnalités

- **Saisie des charges fixes et récurrentes** : nom, montant, fréquence (mensuelle, trimestrielle, semestrielle, annuelle) et jour de prélèvement (1 à 28). Les charges non mensuelles sont automatiquement lissées sur 12 mois.
- **Saisie des revenus** : même principe, avec équivalent mensuel automatique.
- **Curseur des dépenses non prévues** : un curseur réglable au mois pour mettre de côté une enveloppe « imprévus », persistée entre les lancements.
- **Tableau de bord du mois en cours** : revenus mensualisés, charges lissées, montant déjà débité à ce jour, montant encore à débiter, avancement du mois (jour X sur Y), reste à vivre et budget par jour.
- **Projection du mois suivant** : revenus et charges prévues (avec le détail des prélèvements par jour), imprévus estimés au même niveau, reste à vivre projeté et budget par jour.

Les données sont stockées localement sur l'appareil via SwiftData (aucun serveur, aucune donnée transmise).

## Ouvrir et lancer le projet

1. Installer [Xcode 16 ou plus récent](https://developer.apple.com/xcode/) sur un Mac.
2. Ouvrir `MonBudget.xcodeproj` (double-clic ou `open MonBudget.xcodeproj`).
3. Choisir un simulateur d'iPhone et appuyer sur ▶︎ (Cmd+R).

### Sur un iPhone réel

1. Brancher l'iPhone en USB (ou utiliser le Wi-Fi après appairage).
2. Dans Xcode : sélectionner la cible **MonBudget** → onglet **Signing & Capabilities** → choisir votre équipe (un Apple ID gratuit suffit).
3. Sélectionner votre iPhone puis appuyer sur ▶︎. Sur l'iPhone, autoriser le développeur dans Réglages → Général → VPN et gestion de l'appareil si demandé.

## Structure du code

```
MonBudget/
  MonBudgetApp.swift          Point d'entrée + conteneur SwiftData
  Models/
    RecurringItem.swift       Modèle (revenu ou charge récurrente)
  Logic/
    BudgetCalculator.swift    Calendrier de prélèvements et totaux mensualisés
  Views/
    ContentView.swift         Onglets Mois / Récurrents
    MonthDashboardView.swift  Suivi du mois + curseur imprévus + projection
    RecurringListView.swift   Liste des revenus et charges récurrentes
    ItemFormView.swift        Formulaire de saisie / modification
```
