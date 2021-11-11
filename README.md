<p align="center">
  <img src="https://github.com/richardevcom/PAMPy-NFC/blob/main/hero.png?raw=true" alt="NFC"/>
</p>

## Automātiskā instalācija

Uzstādiet `wget` un palaidiet šo attālināto instalācijas skriptu:<br/>
_(varat arī saglabāt savā tīklā un palaist to no sava tīkla)_<br/>

```bash
# Lejupielādēt cURL
sudo apt install curl
# Lejupielādēt instalācijas failu
#sudo wget https://raw.githubusercontent.com/richardevcom/PAMPy-NFC/main/setup/install.sh
sudo wget https://gitlab.bkus.lv/richard.mucelan/PAMPy-NFC/main/setup/install.sh
# Palaist instalācijas failu (obligāti jānorāda API servera adrese -u argumentam)
sudo bash install.sh -u https://10.1.20.28/api/Values/GetValues/
```

⚠️ _Lūdzu pārliecinieties, ka esat norādījuši derīgu pilno API servera adresi, piemēram:_ `http://198.168.1.28/api/Values/GetValues/`

## Manuāla instalācija

1. Pirms uzsākšanas, pārliecinies, ka esi VPN tīklā.
2. Atjaunini sistēmu un tās pakotnes

```bash
apt-get -y update
```

3. Izpako source kodu
1. Izmantojot Git

```bash
apt-get -y install git
git clone https://github.com/richardevcom/PAMPy-NFC.git ppnfc
cd ppnfc  # Neaizmirstam obligāti pāriet uz risinājuma mapi
```

2. Manuāli izpako lejupielādēto arhīva failu

```bash
wget https://github.com/richardevcom/PAMPy-NFC/archive/main.tar.gz
tar -xf main.tar.gz
cd PAMPy-NFC-main   # Neaizmirstam obligāti pāriet uz risinājuma mapi
```

4. Instalē PC/SC pakotnes

```bash
apt-get -y install pcscd pcsc-tools
```

5. Atiestati/nobloķē noklusējuma PC/SC draiverus pievienojot šīs rindiņas faila beigās

```bash
nano /etc/modprobe.d/blacklist.conf
```

```bash
blacklist nfc
blacklist pn533
blacklist pn533_usb
```

6. Instalē jauno PC/SC draiveri

```bash
yes | dpkg -i lib/driver/libacsccid1_1.1.8-1~ubuntu18.04.1_amd64.deb
```

7. Restartē PC/SC servisu

```bash
systemcl restart pcscd
```

8. Uzstādam nepieciešamo Python3 bibliotēku

```bash
apt-get -y install python3 python3-pip python3-pyscard python3-evdev python3-serial python3-filelock python3-psutil python3-cryptography python3-xdo python3-setproctitle python3-requests python3-xlib
```

9. Kopējam `ppnfc_config.py` konfigurācijas failu un rediģējam to

```bash
cp conf/ppnfc_config.py /etc/ppnfc_config.py
nano /etc/ppnfc_config.py
```

Nomainam API adresi `api_endpoint = "http://127.0.0.1/api/"` uz jums nepieciešamo

10. Izvietojam pārējos risinājuma failus

```bash
yes | cp -rf bin/scripts/* /usr/local/bin &>/dev/null
yes | cp -rf conf/services/*.service /lib/systemd/system &>/dev/null
yes | cp -rf conf/ppnfc_pam.config /usr/share/pam-configs &>/dev/null
yes | cp -rf conf/ppnfc_config.py /etc/ &>/dev/null
yes | cp -rf bin/theme/Login.qml /usr/share/sddm/themes/breeze/ &>/dev/null
yes | cp -rf bin/theme/Main.qml /usr/share/sddm/themes/breeze/ &>/dev/null
yes | cp -rf bin/theme/Debug.qml /usr/share/sddm/themes/breeze/components/ &>/dev/null
```

11. Piešķiram minimāli nepieciešamās atļaujas failu palaišanai

```bash
chown -R root:root /usr/local/bin/ppnfc_* &>/dev/null
chown -R root:root /lib/systemd/system/ppnfc_* &>/dev/null
chown -R root:root /etc/ppnfc_config.py &>/dev/null
chmod +x /usr/local/bin/ppnfc_* &>/dev/null
chmod +x /lib/systemd/system/ppnfc_* &>/dev/null
chmod +x /etc/ppnfc_config.py &>/dev/null
```

12. Iestatam un palaižam risinājuma servisus

```bash
systemctl enable ppnfc_server &>/dev/null
systemctl start ppnfc_server &>/dev/null

systemctl enable ppnfc_keyboard_wedge &>/dev/null
systemctl start ppnfc_keyboard_wedge &>/dev/null

systemctl enable ppnfc_auto_send_enter_at_login &>/dev/null
systemctl start ppnfc_auto_send_enter_at_login &>/dev/null
```

13. Pievienojam `nodelay` parametru iekš `/usr/share/pam-configs/unix` faila `AUTH` sadaļas aiz katra `pam_unix.so`.
14. Konfigurējam PAM rediģējot `/etc/pam.d/common-auth` failu un norādot šo risinājumu kā otro autorizācijas posmā

```bash
auth    [success=3 default=ignore]    pam_unix.so nodelay nullok_secure
auth    [success=2 default=ignore]    pam_exec.so quiet /usr/local/bin/ppnfc_pam.py
auth    [success=1 default=ignore]    pam_sss.so use_first_pass
```

## Konfigurācija

Šis risinājums izmanto `/etc/ppnfc_config.py` Python3 failu kā konfigurācijas failu, lai pārrakstītu jeb kuras noklusējuma vērtības iekš `ppnfc_server.py` servera faila.

```bash
nano /etc/ppnfc_config.py

# General - skatiet failus iekš /usr/local/bin - lai redzētu, kādus mainīgos varat rediģēt šajā konfigurācijā.
logout_action = 'logout'  # Izlogot vai slēgt sesiju?

# API (attālināts API serviss)
api_endpoint = "http://127.0.0.1/api/Values/GetValues/"  # API avota pamata URL adrese
api_request_timeout = 5                                   # (n) laiks sekundēs, pēc kura pārtaukt API pieprasījumu

# HTTP
http_read_every = 0.2                   # nolasīt HTTP pieprasījumu ik (n) sekundes
http_uid_not_sent_inactive_timeout = 1  # (n) laiks sekundēs, pēc kura pātraukt gaidīt lietotāja ID iesūtīšanu

# PCSC
pcsc_read_every = 0.2   # nolasīt NFC lasītāju ik (n) sekundes
pcsc_read_timeout = 0.1 # (n) laiks sekundēs, pēc kura pārtraukt gaidīt NFC lasījumu

# ...
```

## Papildus

Iekš `PAMPy-NFC-main/bin/` mapes atrodas fails `ppnfc_usb_reset` - tas ir paredzēts gadījumā, ja NFC lasītājs "uzkaras", vai pašrocīgi izslēdzas.
