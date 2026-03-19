# Guía de Contribución — Tyse Scrutiny

## Reglas de Ramas

### Modelo de ramas

```
main       ← Producción. Solo merges desde develop con PR aprobado.
develop    ← Integración. PRs desde feature branches.
feature/*  ← Ramas de trabajo individual.
hotfix/*   ← Fixes urgentes desde main.
```

### Convención de nombres para feature branches

Cada desarrollador debe usar su prefijo:

```
feature/julian-<descripcion>    ← JulianOrtegon
feature/manuel-<descripcion>    ← Manuel
```

Ejemplos:
- `feature/julian-login-fix`
- `feature/julian-new-report`
- `feature/manuel-kafka-config`

### Ramas protegidas

- **`main`** y **`develop`** están protegidas
- NO se puede hacer push directo a estas ramas
- TODO cambio debe ir a través de un Pull Request (PR)
- Todo PR requiere al menos 1 aprobación de @manuelmottaherrera
- Todo PR debe pasar los checks de CI antes de merge

## Flujo de Trabajo

### 1. Crear tu feature branch

```bash
git checkout develop
git pull origin develop
git checkout -b feature/julian-mi-cambio
```

### 2. Trabajar y hacer commits

```bash
git add <archivos>
git commit -m "feat(modulo): descripción del cambio"
git push -u origin feature/julian-mi-cambio
```

### 3. Crear Pull Request

```bash
gh pr create --base develop --title "feat(modulo): descripción"
```

O desde la interfaz web de GitHub.

### 4. Esperar aprobación

- El CI se ejecutará automáticamente
- Manuel revisará y aprobará (o pedirá cambios)
- Una vez aprobado y CI verde → merge

## Lo que NO debes hacer

- **NO hacer push a `main` o `develop`** directamente
- **NO hacer force push** (`git push --force`) en ninguna rama compartida
- **NO modificar** archivos de CI (`.github/workflows/`)
- **NO modificar** configuración de branch protection
- **NO eliminar ramas** de otros desarrolladores
- **NO modificar** `CODEOWNERS`, `CONTRIBUTING.md`, o `CLAUDE.md`
- **NO commitear** archivos con credenciales, tokens o secretos
- **NO commitear** archivos `.env` (solo `.env.example`)

## Uso seguro de IA (Vibe Coding)

Si usas IA para programar:

1. **Siempre trabaja en tu feature branch** — nunca en develop o main
2. **Revisa los cambios** antes de hacer commit (`git diff`)
3. **No dejes que la IA haga push** directamente
4. **No dejes que la IA modifique** archivos de configuración del proyecto
5. **No compartas credenciales** con la IA
6. **Si algo sale mal**, pide ayuda antes de intentar arreglarlo con force push

## Convención de Commits

```
type(scope): descripción breve
```

| Tipo | Uso |
|------|-----|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `docs` | Solo documentación |
| `style` | Formato, sin cambio de lógica |
| `refactor` | Refactorización sin cambio funcional |
| `test` | Agregar o modificar tests |
| `chore` | Mantenimiento, dependencias |

## Ayuda

Si tienes dudas o algo no funciona, contacta a Manuel antes de hacer cualquier acción destructiva.
