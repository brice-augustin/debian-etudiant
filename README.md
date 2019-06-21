# debian-etudiant
Installation customisée de Debian pour les salles de TP (sur PC ou en VM)

## PC

*Invoqué par le script d'installation de Restore Hope.*

Installe les applications et configure l'environnement utilisé en TP.

## VM

*Utilise Packer et un fichier Preseed.*

```
./build.sh [proxy]
```

Sans paramètre, installe l'OS en CLI, les applications et configure l'environnement utilisé en TP.
Le paramètre `proxy` permet d'utiliser le proxy de l'IUT pendant l'installation.
