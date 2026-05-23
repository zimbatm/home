---
title: Meetup NixOS Suisse Romande - Exercise
created: '2020-05-20'
updated: '2022-01-05'
date: '2020-05-20'
tags:
- French
- Nix
- Meetup
---

Pour cet episode nous allons faire un petit exercise pour apprendre a utiliser NixOS.

## Preparation

1. Installez VirtualBox: [https://www.virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads)
1. Telechargez l'image VirtualBox de NixOS: [https://channels.nixos.org/nixos-20.03/latest-nixos-x86_64-linux.ova](https://channels.nixos.org/nixos-20.03/latest-nixos-x86_64-linux.ova)
1. Chargez l'image dans VirtualBox avec "Fichier" → "Importer l'Appliance" → "Importer"
   Une fois demarer, vous pouvez vous connecter avec l'utilisateur `demo` et mot the passe `demo`. Il egalement est possible d'obtenir l'acces administrateur avec la commande `sudo -i` une fois connecter.

## Exercise 1 - installation de paquet

Ouvrez la configuration systeme avec `sudo nixos-rebuild edit` et changez la configuration.

Trouvez un paquet a installer en parcourant [https://nixos.org/nixos/packages.html?channel=nixos-20.03](https://nixos.org/nixos/packages.html?channel=nixos-20.03) et ajoutez le a `environment.systemPackages`.

Par exemple:

```nix
{
  environment.systemPackages = [
    pkgs.hello
  ];
}
```

Une fois modifier, enregistrez le fichier et executez `sudo nixos-rebuild switch` pour activer la nouvelle configuration.

Vous pouvez tester que la nouvelle configuration se soit activee en executant le programme dans la ligne de command:

```nix
$ hello
Hello, world!
```

## Exercise 2 - configuration de service

Explorez les options dans [https://nixos.org/nixos/packages.html?channel=nixos-20.03](https://nixos.org/nixos/packages.html?channel=nixos-20.03) et choisissez un service a installer.

Tout comme dans l'exercise 1 nous allons ouvrir le fichier de configuration avec `sudo nixos-rebuild edit` , modifier et enregistrer les changements, et finalement executer `nixos-rebuild switch` pour activer la configuration.

Si vous trouvez la syntaxe nix confuse, n'hesitez pas a consulter ce petit guide (en anglais): [https://github.com/tazjin/nix-1p](https://github.com/tazjin/nix-1p)

Prenez notes des etapes et problemes que vous avez rencontrer.

## Exercice 3 - retour sur une ancienne configuration

Redemarrer la VM avec `reboot`. Dans le menu de demarrage vous trouverez toutes les version precedentes de la configuration systeme.

Chosissez une ancienne version et demarrer la machine avec. Constatez que vous etes bien retourner dans un etat precedent en consultant l'etat systeme. (par exemple avec `systemctl status` ou en executant un des programmes.

```nix
$ hello
hello: command not found
```

## Exercise 4 - reclamez de l'espace

Redemarrer le systeme a la derniere configuration ou lancez `nixos-rebuild switch`.

Lancez `df -h` pour voir combien d'espace disque est disponible.

Nous allons maintenant supprimer les anciennes configurations. Lances `sudo nix-collect-garbage -d` pour effacer les vieux profiles et fichiers associes.

Voila, vous pouvez maintenant constanter que vous avec plus d'espace disponible en lancant `df -h` a nouveau.
