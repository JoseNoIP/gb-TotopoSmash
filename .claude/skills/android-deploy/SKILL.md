# Skill: /android-deploy

Configura o repara el pipeline de CI/CD de GitHub Actions para publicar un juego Godot 4.x en Google Play Store como AAB firmado.

Usa este skill cuando:
- Estás configurando el pipeline por primera vez en un nuevo juego
- Un paso del workflow está fallando y quieres el mapa completo de errores conocidos

---

## Arquitectura del pipeline (Godot 4.7+)

```
Checkout → Java 17 → Instalar Godot → Instalar templates
→ Configurar keystore + version_code → Pre-heat cache
→ Export APK (instala template Gradle + popula assets)
→ bundleRelease (produce AAB)
→ jarsigner (firma el AAB explícitamente)
→ Subir artefacto → Upload a Play Store
```

El flujo **dos pasos** es obligatorio en Godot 4.7:
1. `godot --export-release ... game.apk` — Godot exporta APK y popula `android/build/` con los assets del juego.
2. `./gradlew bundleRelease` — Gradle produce el AAB que Play Store requiere.
3. `jarsigner` — firma el AAB explícitamente (Gradle puede producirlo sin firma aunque se pasen los flags `-P`).

Godot 4.7 **rechaza** la extensión `.aab` directamente. El AAB solo se puede producir vía Gradle.

---

## Version code — estándar recomendado

**Usar minutos desde 2024-01-01:**
```bash
echo "version_code=$(( ($(date +%s) - 1704067200) / 60 ))" >> $GITHUB_OUTPUT
```

- ~815,000 hoy (julio 2026), crece ~525,000/año
- Nunca colisiona con versiones subidas manualmente
- Válido por siglos (muy lejos del límite 2,100,000,000 de Play Store)
- El `version_code` es **interno** — usuarios nunca lo ven (ellos ven `version_name`)

**No usar:**
- `github.run_number` — colisiona si subes algo manualmente (empieza en 1)
- Unix epoch (`date +%s`) — válido pero más largo (~1.75B) y expira ~2038

---

## Workflow completo — probado y funcional

```yaml
name: Deploy → Google Play

on:
  push:
    branches: [main]
    tags: ["v*.*.*"]
  workflow_dispatch:
    inputs:
      skip_upload:
        description: "Solo construir AAB (sin subir a Play Store)"
        type: boolean
        default: false

env:
  GODOT_VERSION: "4.7"                        # cambiar según versión del proyecto
  EXPORT_PRESET: "Android"                    # debe coincidir con export_presets.cfg
  PACKAGE_NAME: "com.tuempresa.tujuego"       # ← CAMBIAR

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Determinar track y versión
        id: ctx
        run: |
          if [[ "${{ github.ref }}" == refs/tags/* ]]; then
            echo "track=production" >> $GITHUB_OUTPUT
          else
            echo "track=internal"   >> $GITHUB_OUTPUT
          fi
          # Minutos desde 2024-01-01: compacto, siempre creciente, nunca colisiona
          echo "version_code=$(( ($(date +%s) - 1704067200) / 60 ))" >> $GITHUB_OUTPUT

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17

      - name: Instalar Godot ${{ env.GODOT_VERSION }}
        run: |
          wget -q "https://github.com/godotengine/godot/releases/download/${{ env.GODOT_VERSION }}-stable/Godot_v${{ env.GODOT_VERSION }}-stable_linux.x86_64.zip" -O godot.zip
          unzip -q godot.zip
          mv "Godot_v${{ env.GODOT_VERSION }}-stable_linux.x86_64" /usr/local/bin/godot
          chmod +x /usr/local/bin/godot
          rm godot.zip

      - name: Instalar export templates
        run: |
          wget -q "https://github.com/godotengine/godot/releases/download/${{ env.GODOT_VERSION }}-stable/Godot_v${{ env.GODOT_VERSION }}-stable_export_templates.tpz" -O templates.tpz
          TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${{ env.GODOT_VERSION }}.stable"
          mkdir -p "$TEMPLATES_DIR"
          unzip -q templates.tpz -d templates_tmp
          mv templates_tmp/templates/* "$TEMPLATES_DIR/"
          rm -rf templates_tmp templates.tpz

      - name: Configurar keystore y version code
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > /tmp/game.keystore
          sed -i "s|version/code=[0-9]*|version/code=${{ steps.ctx.outputs.version_code }}|" export_presets.cfg
          sed -i "s|gradle_build/use_gradle_build=false|gradle_build/use_gradle_build=true|" export_presets.cfg
          grep -E "version/code|gradle_build/use" export_presets.cfg

      - name: Pre-heat Godot cache
        run: godot --headless --editor --quit || true

      - name: Exportar APK (instala template + popula android/build/)
        env:
          GODOT_ANDROID_KEYSTORE_RELEASE_PATH: /tmp/game.keystore
          GODOT_ANDROID_KEYSTORE_RELEASE_USER: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASS }}
        run: |
          mkdir -p builds/
          godot --headless --verbose \
            --install-android-build-template \
            --export-release "${{ env.EXPORT_PRESET }}" \
            "builds/game.apk"

      - name: Construir AAB con Gradle
        env:
          KEYSTORE_ALIAS: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          KEYSTORE_PASS: ${{ secrets.ANDROID_KEYSTORE_PASS }}
        run: |
          mkdir -p android/build/assetPackInstallTime/src/main/assets

          cd android/build
          # PROPIEDADES CRÍTICAS de config.gradle (Godot 4.7):
          #   export_package_name  → applicationId (default: com.godot.game)
          #   export_version_code  → versionCode   (default: 1 — SIEMPRE PASAR)
          #   perform_signing=true → activa signingConfig release (default: false)
          #   release_keystore_*   → datos del keystore
          ./gradlew bundleRelease \
            "-Pexport_package_name=${{ env.PACKAGE_NAME }}" \
            "-Pexport_version_code=${{ steps.ctx.outputs.version_code }}" \
            "-Pperform_signing=true" \
            "-Prelease_keystore_file=/tmp/game.keystore" \
            "-Prelease_keystore_password=$KEYSTORE_PASS" \
            "-Prelease_keystore_alias=$KEYSTORE_ALIAS"

          AAB=$(find . -name "*.aab" -path "*/standardRelease/*" | head -1)
          if [ -z "$AAB" ]; then
            AAB=$(find . -name "*.aab" -not -path "*/intermediates/*" | head -1)
          fi
          cp "$AAB" ../../builds/game.aab

      # Firmar explícitamente: bundleRelease puede ignorar -Pperform_signing
      # en algunas configuraciones de Godot. jarsigner v1 es suficiente para
      # Google Play App Signing (Google re-firma al distribuir).
      - name: Firmar AAB con jarsigner
        env:
          KEYSTORE_ALIAS: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          KEYSTORE_PASS: ${{ secrets.ANDROID_KEYSTORE_PASS }}
        run: |
          jarsigner \
            -verbose \
            -sigalg SHA256withRSA \
            -digestalg SHA-256 \
            -keystore /tmp/game.keystore \
            -storepass "$KEYSTORE_PASS" \
            -keypass "$KEYSTORE_PASS" \
            builds/game.aab \
            "$KEYSTORE_ALIAS"
          jarsigner -verify builds/game.aab
          echo "✓ AAB firmado"

      - name: Guardar AAB como artefacto
        uses: actions/upload-artifact@v4
        with:
          name: aab-${{ steps.ctx.outputs.track }}-${{ github.run_number }}
          path: builds/game.aab
          retention-days: 30

      - name: Subir a Google Play — ${{ steps.ctx.outputs.track }}
        if: ${{ github.event_name != 'workflow_dispatch' || inputs.skip_upload == false }}
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_JSON }}
          packageName: ${{ env.PACKAGE_NAME }}
          releaseFiles: builds/game.aab
          track: ${{ steps.ctx.outputs.track }}
          status: completed
```

---

## GitHub Secrets requeridos

| Secret | Cómo obtenerlo |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i mi.keystore` (en Mac: `base64 -i mi.keystore -o -`) |
| `ANDROID_KEYSTORE_ALIAS` | El alias que usaste al crear el keystore con `keytool` |
| `ANDROID_KEYSTORE_PASS` | La contraseña del keystore (y del key, si son iguales) |
| `GOOGLE_PLAY_JSON` | Play Console → Configuración → Cuentas de servicio → JSON |

---

## export_presets.cfg — requisitos mínimos

```ini
[preset.0]
name="Android"           # debe coincidir con EXPORT_PRESET en el workflow

[preset.0.options]
package/unique_name="com.tuempresa.tujuego"
gradle_build/use_gradle_build=false   # el CI lo activa via sed
version/code=1                        # el CI lo sobreescribe con sed
version/name="1.0"                    # lo que ve el usuario en Play Store
```

---

## Errores conocidos y sus soluciones exactas

### `Trying to build from a gradle built template, but no version info for it exists`
**Causa:** `.build_version` ausente o con contenido incorrecto.
**Solución:** Usar `--install-android-build-template`. Nunca escribir `.build_version` manualmente.

### `Android APK requires the *.apk extension`
**Causa:** Godot 4.7 no exporta directo a `.aab`.
**Solución:** Exportar a `.apk`. El AAB se produce con `./gradlew bundleRelease`.

### `All uploaded bundles must be signed. Please sign using jarsigner`
**Causa:** `bundleRelease` puede ignorar `-Pperform_signing=true` según la configuración del template. El AAB sale sin firma de release.
**Solución:** Agregar paso explícito de `jarsigner` después de `bundleRelease`. El mensaje de error de Play Store literalmente dice qué herramienta usar. Ver el template de workflow arriba.

### `Version code X has already been used`
**Causa:** El version code del AAB siempre es `1` porque `config.gradle` usa ese default si no se le pasa `-Pexport_version_code`. El `sed` sobre `export_presets.cfg` le llega a Godot (para el APK) pero NO a Gradle (para el AAB).
**Solución:** Pasar `-Pexport_version_code=${{ steps.ctx.outputs.version_code }}` a `bundleRelease`. **Ambos** el `sed` y el `-P` son necesarios.

### `APK has the wrong package name` / `com.godot.game.fileprovider`
**Causa:** `config.gradle` usa `com.godot.game` como default.
**Solución:** Pasar `-Pexport_package_name=com.tuempresa.tujuego` a `bundleRelease`.

### `assetPackInstrumentedReleasePreBundleTask FAILED`
**Causa:** Falta el directorio `assetPackInstallTime/src/main/assets`.
**Solución:** `mkdir -p android/build/assetPackInstallTime/src/main/assets` antes de Gradle.

### Primera subida falla con error genérico de la API
**Causa:** La API de Google Play rechaza la primera subida si no existe ninguna versión previa.
**Solución:** Descargar el AAB del artefacto de CI y subirlo **manualmente** una vez desde Play Console. Después, el CI funciona automáticamente.

---

## Advertencias de Play Store (ignorables)

Play Store muestra estas advertencias para **todos** los juegos hechos con Godot. No bloquean la publicación:

| Advertencia | Por qué aparece | Acción |
|---|---|---|
| "No hay archivo de desofuscación (R8/Proguard)" | R8/ProGuard es para código Java/Kotlin. Godot usa GDScript/C++, no pasa por ese proceso. | Ignorar permanentemente |
| "Código nativo sin símbolos de depuración" | Godot exporta librerías `.so` del motor en C++. Los símbolos requieren compilar Godot desde fuente. | Ignorar salvo crashes frecuentes en el motor |

---

## Propiedades de config.gradle (Godot 4.7) — referencia completa

| Propiedad | Default | Descripción |
|---|---|---|
| `export_package_name` | `com.godot.game` | applicationId del APK/AAB |
| `export_version_code` | `1` | versionCode — **siempre pasar explícitamente** |
| `export_version_name` | `1.0` | versionName (visible al usuario) |
| `perform_signing` | `false` | Intenta activar signingConfig — no siempre funciona, usar jarsigner además |
| `release_keystore_file` | `.` | Ruta absoluta al .keystore |
| `release_keystore_password` | `""` | Store password |
| `release_keystore_alias` | `""` | Key alias |

---

## Variantes de build en Godot 4.7

`bundleRelease` genera tres variantes. Usar siempre `standardRelease`:
- `standardRelease` — producción normal ✓
- `monoRelease` — con .NET/C#
- `instrumentedRelease` — para tests de instrumentación

El AAB queda en: `android/build/app/build/outputs/bundle/standardRelease/*.aab`

---

## Notas de Play Console

- **Track interno:** push a `main` → Internal Testing (sin revisión de Google).
- **Producción:** tag `v*.*.*` → Production (pasa por revisión de Google).
- El campo que ve el usuario en la tienda es `version/name` (ej. "1.0"), no `version/code`.
