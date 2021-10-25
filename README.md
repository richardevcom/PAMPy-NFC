## Automātiskā instalācija

Uzstādiet `wget` un palaidiet šo attālināto instalācijas skriptu:<br/>
_(varat arī saglabāt savā tīklā un palaist to no sava tīkla)_<br/>

```bash
# Lejupielādēt cURL
sudo apt install curl
# Lejupielādēt instalācijas failu
sudo wget https://raw.githubusercontent.com/richardevcom/PAMPy-NFC/main/setup/install.sh
# Palaist instalācijas failu (obligāti jānorāda API servera adrese -u argumentam)
sudo bash install.sh -u http://server_ip/api/
```

## Konfigurācija

Šis risinājums izmanto `/etc/ppnfc_config.py` Python3 failu kā konfigurācijas failu, lai pārrakstītu jeb kuras noklusējuma vērtības iekš `ppnfc_server.py` servera faila.

```bash
/etc/ppnfc_config.py
```
