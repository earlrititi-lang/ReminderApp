# Generar el `.ipa` desde Windows con GitHub Actions

Este proyecto no puede generar un `.ipa` directamente en Windows. La build de iOS se ejecuta en GitHub Actions sobre `macos`, y luego descargas el artefacto resultante en tu PC.

## 1. Crear el repositorio remoto

1. Crea un repositorio vacío en GitHub.
2. Copia su URL `https` o `ssh`.

## 2. Inicializar y subir este proyecto

Ejecuta estos comandos dentro de `C:\Users\lorit\PROYECTOS\REMINDER\reminder_app`:

```powershell
git init -b main
git add .
git commit -m "Initial import"
git remote add origin <URL_DE_TU_REPO>
git push -u origin main
```

## 3. Lanzar la build

Tienes dos formas:

- Hacer `push` a `main`
- O ir a `GitHub > Actions > Build iOS Unsigned IPA > Run workflow`

## 4. Descargar el artefacto

Cuando termine la ejecución:

1. Entra en la ejecución del workflow
2. Baja a `Artifacts`
3. Descarga `ios-unsigned-ipa`
4. Descomprime el `.zip`

Dentro encontrarás:

```text
reminder_app-unsigned.ipa
```

## 5. Instalarlo con AltStore

En el iPhone:

1. Abre `AltStore`
2. Ve a `My Apps`
3. Pulsa `+`
4. Selecciona `reminder_app-unsigned.ipa`

AltStore lo firmará con tu Apple ID e instalará la app.

## Si falla la build

Lo más normal es uno de estos casos:

- Dependencias de iOS rotas en `Podfile` o Pods
- Plugin de Flutter incompatible con iOS
- Error del runner de GitHub al resolver CocoaPods

Si pasa, abre el log de la acción y corrige el error en el repo.
