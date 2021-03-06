# DDOSProtection


### Get configuration iptable

Be careful the use of the script can make your system unstable, it is not always finished in development

```bash
wget -O - https://raw.githubusercontent.com/Ghost-devlopper/DDOSProtection/master/iptable-configuration.sh | sudo bash
```

### IPtables Tables

Filtrer : La table de filtrage est la table par défaut et la plus couramment utilisée, vers laquelle les règles vont si vous n'utilisez pas l'option -t (--table).

NAT : Cette table est utilisée pour la traduction d'adresses de réseau (NAT). Si un paquet crée une nouvelle connexion, la table de natation est vérifiée pour les règles.

Mangle : La table de mangle est utilisée pour modifier ou marquer les paquets et leurs informations d'en-tête.

Raw : Ce tableau vise principalement à exclure certains paquets du suivi des connexions en utilisant la cible NOTRACK.

Comme vous pouvez le voir, il y a quatre tables différentes sur un système Linux moyen qui n'a pas de modules de noyau non standard chargés. Chacun de ces tableaux supporte un ensemble différent de chaînes iptables.

### IPtables Chains

PREROUTING: raw, nat, mangle
- S'applique aux paquets qui entrent dans la carte d'interface réseau (NIC)

INPUT: filter, mangle
- S'applique aux paquets destinés à une prise locale

FORWARD: filter, mangle
- S'applique aux paquets qui sont acheminés par le serveur

SORTIE : brut, filtre, nat, mangle
- S'applique aux paquets que le serveur envoie (générés localement)

POSTROUTING: nat, mangle
- S'applique aux paquets qui quittent le serveur

Change Iptables LOG File Name
-----------------------------

To change iptables log file name edit /etc/rsyslog.conf file and add following configuration in file.

`vi /etc/syslog.conf`

Add the following line

`kern.warning /var/log/iptables.log`

Now, restart rsyslog service using the following command.

`service rsyslog restart`

Display log iptables
-----------------------------

`tail -f /var/log/kern.log`
