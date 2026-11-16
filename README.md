# EdgeTX OLED autobuild

Automatyczne budowanie firmware EdgeTX z włączonym sterownikiem **SSD1309**
dla przeróbki z wyświetlaczem OLED 2,42" 128×64 SPI
([DongkwanYi/OLEDBOXER](https://github.com/DongkwanYi/OLEDBOXER)).

Obsługiwane radia: Radiomaster **Boxer**, TX12, TX12 MK2, Zorro, Pocket, MT12, Jumper T12 MAX.

## Jak to działa

Codziennie o 03:17 UTC workflow [`build.yml`](.github/workflows/build.yml):

1. sprawdza najnowsze stabilne wydanie EdgeTX (najwyższy numer wersji),
2. jeśli nie ma jeszcze wydania `oled-vX.Y.Z` w tym repo, pobiera kod EdgeTX,
3. nakłada łatkę [`scripts/apply-oled-patch.sh`](scripts/apply-oled-patch.sh),
4. buduje firmware i bootloader dla każdego radia w kontenerze `edgetx-dev`
   (tym samym, którego używa EdgeTX),
5. publikuje wynik jako **pre-release** w zakładce *Releases*.

### Łatka

Od EdgeTX 2.10 kod sterownika SSD1309 jest już w źródłach (używa go np. Jumper T14).
Wystarczy go włączyć — skrypt dopisuje w `radio/src/targets/taranis/hal.h`
zaraz po komentarzu `// LCD driver`:

```c
#define OLED_SCREEN
#define SSD1309_LCD
```

To ta sama zmiana, której używa autor przeróbki (zob. issue #12 w jego repo).
Jeśli EdgeTX zmieni strukturę plików, skrypt kończy się błędem i nic nie jest
publikowane — wtedy trzeba poprawić łatkę.

## Ręczne uruchomienie

*Actions → Build OLED firmware → Run workflow*. Można podać:

- `version` – konkretny tag, np. `v2.11.8` (puste = najnowszy),
- `stick_mode` – domyślny tryb drążków (1–4, domyślnie 2),
- `force` – zbuduj ponownie, nawet jeśli wydanie już istnieje.

## Wgrywanie

1. Podłącz **oryginalny LCD**, wgraj `OLED<RADIO>-<wersja>.bin` z karty SD.
2. Wyłącz radio, odłącz LCD, podłącz OLED.
3. Włącz radio: SYS → karta SD → `FIRMWARE` → `OLED<RADIO>-<wersja>-bootloader.bin` → *Flash bootloader*.
4. Sprawdź tryb drążków.

⚠️ Buildy **nie są testowane na sprzęcie**. Po sprawdzeniu na radiu można
zmienić pre-release na zwykłe wydanie.

## Budowanie lokalnie (Docker)

```bash
git clone --recursive --branch v2.12.5 https://github.com/EdgeTX/edgetx.git
bash scripts/apply-oled-patch.sh edgetx
docker run --rm -v "$PWD:/workspaces" -w /workspaces/edgetx -e TARGET=boxer -e VERSION=2.12.5 -e OUT_DIR=/workspaces/out \
  ghcr.io/edgetx/edgetx-dev:2.12 bash /workspaces/scripts/build.sh
```

## Licencja

EdgeTX jest na licencji GPLv2; zbudowane firmware również. Przeróbka OLED:
[DongkwanYi](https://github.com/DongkwanYi/OLEDBOXER), kod OLED: Brain (Y.S. Cho).
