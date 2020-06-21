#!/bin/bash
# Script béta test pour faire des réglages dans iptable.

###################################
#     Ajout des filtres           #
###################################

iptables -P INPUT DROP
iptables -t filter -N LOG_N_ACCEPT
iptables -t filter -A LOG_N_ACCEPT -j LOG --log-level warning --log-prefix "ACTION=INPUT-ACCEPT "
iptables -t filter -A LOG_N_ACCEPT -j ACCEPT

###################################
#     première configuration      #
###################################

iptables -A INPUT -i eno1 -j LOG_N_ACCEPT                                      # Autoriser les flux en localhost
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j LOG_N_ACCEPT  # Autoriser les connexions déjà établies,
iptables -A INPUT -p tcp -m tcp --dport 22 -j LOG_N_ACCEPT                    # Autoriser SSH,
iptables -A INPUT -p tcp -m tcp --dport http -j LOG_N_ACCEPT                  # Autoriser HTTP,
iptables -A INPUT -p tcp -m tcp --dport https -j LOG_N_ACCEPT                 # Autoriser HTTPS,
iptables -P INPUT DROP                                                 # Politique par défaut de la table INPUT : DROP. (i.e bloquer tout le reste).
iptables -P FORWARD DROP                                               # On est pas un routeur ou un NAT pour un réseau privé, on ne forward pas de paquet.


###################################
#     Seconde configuration       #
###################################

# We can simply use following command to enable logging in iptables.
/sbin/iptables -A INPUT -j LOG

# We can also define the source ip or range for which log will be created.
/sbin/iptables -A INPUT -s 192.168.10.0/24 -j LOG

#To define level of LOG generated by iptables us –log-level followed by level number.
/sbin/iptables -A INPUT -s 192.168.10.0/24 -j LOG --log-level 4

#We can also add some prefix in generated Logs, So it will be easy to search for logs in a huge file.
/sbin/iptables -A INPUT -s 192.168.10.0/24 -j LOG --log-prefix "** SUSPECT **"

### 1: Drop invalid packets ### 
/sbin/iptables -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP  

### 2: Drop TCP packets that are new and are not SYN ### 
/sbin/iptables -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP 
 
### 3: Drop SYN packets with suspicious MSS value ### 
/sbin/iptables -t mangle -A PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j DROP  

### 4: Block packets with bogus TCP flags ### 
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP 
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP 
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -j DROP 
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,ACK FIN -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,URG URG -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL ALL -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL NONE -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP
/sbin/iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

### 5: Block spoofed packets ### 
/sbin/iptables -t mangle -A PREROUTING -s 224.0.0.0/3 -j DROP
/sbin/iptables -t mangle -A PREROUTING -s 169.254.0.0/16 -j DROP
/sbin/iptables -t mangle -A PREROUTING -s 172.16.0.0/12 -j DROP
/sbin/iptables -t mangle -A PREROUTING -s 192.0.2.0/24 -j DROP
/sbin/iptables -t mangle -A PREROUTING -s 192.168.0.0/16 -j DROP
/sbin/iptables -t mangle -A PREROUTING -s 10.0.0.0/8 -j DROP --log-prefix "** Block spoofed **"
/sbin/iptables -t mangle -A PREROUTING -s 0.0.0.0/8 -j DROP --log-prefix "** Block spoofed **"
/sbin/iptables -t mangle -A PREROUTING -s 240.0.0.0/5 -j DROP --log-prefix "** Block spoofed **"
/sbin/iptables -t mangle -A PREROUTING -s 127.0.0.0/8 ! -i lo -j DROP  --log-prefix "** Block spoofed **"

### 6: Drop ICMP (you usually don't need this protocol) ### 
/sbin/iptables -t mangle -A PREROUTING -p icmp -j DROP  

### 7: Drop fragments in all chains ### 
/sbin/iptables -t mangle -A PREROUTING -f -j DROP  

### 8: Limit connections per source IP ### 
/sbin/iptables -A INPUT -p tcp -m connlimit --connlimit-above 111 -j REJECT --reject-with tcp-reset  

### 9: Limit RST packets ### 
/sbin/iptables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j LOG_N_ACCEPT  
/sbin/iptables -A INPUT -p tcp --tcp-flags RST RST -j DROP  

### 10: Limit new TCP connections per second per source IP ### 
/sbin/iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j LOG_N_ACCEPT  
/sbin/iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j DROP  

### 11: Use SYNPROXY on all ports (disables connection limiting rule) ### 
# Hidden - unlock content above in "Mitigating SYN Floods With SYNPROXY" section

### SSH brute-force protection ### 
/sbin/iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --set 
/sbin/iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 -j DROP  

### Protection against port scanning ### 
/sbin/iptables -N port-scanning 
/sbin/iptables -A port-scanning -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j RETURN 
/sbin/iptables -A port-scanning -j DROP

###################################
#     Troisième configuration     #
###################################

### PROTECTION SYNFLOOD 
/sbin/iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j LOG_N_ACCEPT

### PROTECTION PINGFLOOD
/sbin/iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT

### PROTECTION SCAN PORT
/sbin/iptables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 1/h -j LOG_N_ACCEPT
/sbin/iptables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/h -j LOG_N_ACCEPT

###################################
#     Connexion en sorties        #
###################################

iptables -I OUTPUT -m state -p tcp --state NEW ! -s 127.0.0.1 ! -d 127.0.0.1 -j LOG --log-prefix "ACTION=OUTPUT-TCP "
iptables -I OUTPUT -m state -p udp -s 127.0.0.1 ! -d 127.0.0.1 -j LOG --log-prefix "ACTION=OUTPUT-UDP "

###################################
#         Fin du script           #
###################################

apt-get install iptables-persistent
iptables-save > /etc/iptables/rules.v4
systemctl restart rsyslog

tail -f /var/log/kern.log
