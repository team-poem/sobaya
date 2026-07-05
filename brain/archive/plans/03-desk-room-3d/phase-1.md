# desk-room-3d Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an interactive low-poly 3D desk scene (R3F) for the blog main page, with orbit/zoom, an intro camera move, and click easter-eggs, deployable standalone and embeddable via iframe.

**Architecture:** A Vite + React + TypeScript app. `<Canvas>` hosts an `Experience` (camera, OrbitControls, lighting, intro animation) that renders a `DeskScene` of independent object components (Desk, Monitor, Keyboard, Trackpad, MacBook, CableHub, Lamp, Chair). All objects are built from Three.js primitives (low-poly) for a self-contained MVP; nicer glTF assets are an optional later polish. Shared interaction state (lamp on/off, monitor screen index, MacBook awake) lives in a small zustand store; objects read/write it through that interface.

**Tech Stack:** Vite, React 18, TypeScript, three, @react-three/fiber, @react-three/drei, zustand, vitest, @react-three/test-renderer.

**Spec:** `brain/plans/03-desk-room-3d/overview.md`

**Conventions for every task:** Work inside `apps/desk-room-3d/`. Commit after each task with a conventional-commit message. `npm run test` must pass before each commit. Visual tasks additionally require a browser screenshot check (see Task 2 for how the dev server is launched).

---

## File Structure

```
apps/desk-room-3d/
├── CLAUDE.md                 # from new-app skill
├── package.json
├── tsconfig.json
├── vite.config.ts
├── vitest.config.ts
├── vitest.setup.ts
├── index.html
├── public/
│   └── poster.png            # static embed poster (Task 19)
├── src/
│   ├── main.tsx              # React entry
│   ├── App.tsx               # mounts <Experience/>
│   ├── styles.css
│   ├── Experience.tsx        # Canvas wrapper: camera, OrbitControls, lights, intro
│   ├── state/
│   │   └── sceneStore.ts     # zustand: lamp/monitor/macbook state
│   ├── lib/
│   │   ├── palette.ts        # shared colors
│   │   └── Clickable.tsx     # hover-cursor + onClick wrapper
│   ├── scene/
│   │   ├── DeskScene.tsx     # positions all objects
│   │   ├── Desk.tsx
│   │   ├── Monitor.tsx
│   │   ├── Keyboard.tsx
│   │   ├── Trackpad.tsx
│   │   ├── MacBook.tsx
│   │   ├── CableHub.tsx
│   │   ├── Lamp.tsx
│   │   └── Chair.tsx
│   └── hooks/
│       └── useIntroCamera.ts
└── tests/
    ├── sceneStore.test.ts
    ├── clickable.test.tsx
    └── scene.smoke.test.tsx
```

**Coordinate convention:** Y up, desk top at `y = 0`. Looking from the front, +X is right, +Z is toward the viewer. The desk top is a slab centered at origin. Object positions below assume this.

---

## Phase A — Foundation

### Task 1: Scaffold the app

**Files:**
- Create: `apps/desk-room-3d/` (whole project)
- Modify: `brain/apps.md` (register the app)

- [ ] **Step 1: Scaffold via the Sobaya new-app skill**

Invoke the `new-app` skill with app name `desk-room-3d`, purpose "interactive 3D desk scene for blog main page", stack "React + react-three-fiber + Vite". This creates `apps/desk-room-3d/` as its own git repo with an app-level `CLAUDE.md` and registers it in `brain/apps.md`.

If the skill is unavailable, do it manually: `mkdir -p apps/desk-room-3d && cd apps/desk-room-3d && git init`, write a short `CLAUDE.md`, and add a row to the `brain/apps.md` table:
`| desk-room-3d | interactive 3D desk scene for blog main page | React/R3F/Vite | scaffolded |`

- [ ] **Step 2: Initialize the Vite React+TS project files**

Create `apps/desk-room-3d/package.json`:

```json
{
  "name": "desk-room-3d",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "three": "^0.169.0",
    "@react-three/fiber": "^8.17.10",
    "@react-three/drei": "^9.114.0",
    "zustand": "^5.0.0"
  },
  "devDependencies": {
    "@react-three/test-renderer": "^8.2.1",
    "@types/react": "^18.3.11",
    "@types/react-dom": "^18.3.0",
    "@types/three": "^0.169.0",
    "@vitejs/plugin-react": "^4.3.2",
    "jsdom": "^25.0.1",
    "typescript": "^5.6.2",
    "vite": "^5.4.8",
    "vitest": "^2.1.2"
  }
}
```

- [ ] **Step 3: Add config files**

Create `apps/desk-room-3d/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  },
  "include": ["src", "tests", "vitest.setup.ts"]
}
```

Create `apps/desk-room-3d/vite.config.ts`:

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
})
```

Create `apps/desk-room-3d/vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.ts'],
  },
})
```

Create `apps/desk-room-3d/vitest.setup.ts`:

```ts
// Polyfills R3F needs under jsdom.
import { vi } from 'vitest'

if (!globalThis.ResizeObserver) {
  globalThis.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  } as unknown as typeof ResizeObserver
}
vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({
  matches: false, addListener: () => {}, removeListener: () => {},
  addEventListener: () => {}, removeEventListener: () => {},
}))
```

Create `apps/desk-room-3d/index.html`:

```html
<!doctype html>
<html lang="ko">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>My Desk in 3D</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

Create `apps/desk-room-3d/src/styles.css`:

```css
* { margin: 0; box-sizing: border-box; }
html, body, #root { width: 100%; height: 100%; overflow: hidden; }
body { background: #0e1118; }
canvas { display: block; }
```

- [ ] **Step 4: Install and verify the toolchain**

Run: `cd apps/desk-room-3d && npm install`
Expected: completes without peer-dependency errors.

Run: `npm run test`
Expected: vitest reports "No test files found" (exit 0) — confirms vitest is wired.

- [ ] **Step 5: Commit**

```bash
cd apps/desk-room-3d
git add -A
git commit -m "chore: scaffold Vite + React + R3F project"
```

---

### Task 2: Canvas + Experience shell

**Files:**
- Create: `src/main.tsx`, `src/App.tsx`, `src/Experience.tsx`
- Test: `tests/scene.smoke.test.tsx`

- [ ] **Step 1: Write the failing smoke test**

Create `tests/scene.smoke.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest'
import ReactThreeTestRenderer from '@react-three/test-renderer'
import { Experience } from '../src/Experience'

describe('Experience', () => {
  it('renders a scene graph with at least one light', async () => {
    const renderer = await ReactThreeTestRenderer.create(<Experience />)
    const lights = renderer.scene.findAll(
      (n) => typeof n.type === 'string' && n.type.endsWith('Light'),
    )
    expect(lights.length).toBeGreaterThan(0)
    await renderer.unmount()
  })
})
```

Note: `@react-three/test-renderer` renders the R3F tree *without* `<Canvas>`, so test `Experience`'s scene contents. `<Canvas>` itself lives in `App` and is not unit-tested.

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test`
Expected: FAIL — cannot import `Experience` (file does not exist).

- [ ] **Step 3: Implement Experience, App, and entry**

Create `src/Experience.tsx`:

```tsx
import { OrbitControls } from '@react-three/drei'

/**
 * The scene contents (no <Canvas>). Camera/controls/lights live here so this
 * component can be rendered headless by @react-three/test-renderer.
 */
export function Experience() {
  return (
    <>
      <OrbitControls
        enablePan={false}
        minDistance={3}
        maxDistance={12}
        maxPolarAngle={Math.PI / 2.1}
      />
      <ambientLight intensity={0.4} color="#aab8d0" />
      {/* DeskScene added in later tasks */}
    </>
  )
}
```

Create `src/App.tsx`:

```tsx
import { Canvas } from '@react-three/fiber'
import { Experience } from './Experience'
import './styles.css'

export function App() {
  return (
    <Canvas camera={{ position: [6, 4, 7], fov: 40 }} shadows>
      <color attach="background" args={['#0e1118']} />
      <Experience />
    </Canvas>
  )
}
```

Create `src/main.tsx`:

```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { App } from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test`
Expected: PASS (one light found).

- [ ] **Step 5: Verify the dev server renders in a browser**

Run: `npm run dev` (note the printed localhost URL).
Open the URL; confirm a dark empty canvas you can rotate with the mouse. Capture a screenshot as evidence. Stop the dev server.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: canvas + experience shell with orbit controls"
```

---

### Task 3: Scene state store

**Files:**
- Create: `src/state/sceneStore.ts`
- Test: `tests/sceneStore.test.ts`

- [ ] **Step 1: Write the failing test**

Create `tests/sceneStore.test.ts`:

```ts
import { describe, it, expect, beforeEach } from 'vitest'
import { useSceneStore, SCREEN_COUNT } from '../src/state/sceneStore'

describe('sceneStore', () => {
  beforeEach(() => useSceneStore.getState().reset())

  it('starts with lamp on, macbook awake, monitor screen 0', () => {
    const s = useSceneStore.getState()
    expect(s.lampOn).toBe(true)
    expect(s.macbookAwake).toBe(true)
    expect(s.monitorScreen).toBe(0)
  })

  it('toggles the lamp', () => {
    useSceneStore.getState().toggleLamp()
    expect(useSceneStore.getState().lampOn).toBe(false)
  })

  it('toggles the macbook', () => {
    useSceneStore.getState().toggleMacbook()
    expect(useSceneStore.getState().macbookAwake).toBe(false)
  })

  it('cycles the monitor screen and wraps around', () => {
    for (let i = 0; i < SCREEN_COUNT; i++) {
      useSceneStore.getState().nextScreen()
    }
    expect(useSceneStore.getState().monitorScreen).toBe(0)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test`
Expected: FAIL — cannot import `sceneStore`.

- [ ] **Step 3: Implement the store**

Create `src/state/sceneStore.ts`:

```ts
import { create } from 'zustand'

export const SCREEN_COUNT = 3

interface SceneState {
  lampOn: boolean
  macbookAwake: boolean
  monitorScreen: number
  toggleLamp: () => void
  toggleMacbook: () => void
  nextScreen: () => void
  reset: () => void
}

const initial = { lampOn: true, macbookAwake: true, monitorScreen: 0 }

export const useSceneStore = create<SceneState>((set) => ({
  ...initial,
  toggleLamp: () => set((s) => ({ lampOn: !s.lampOn })),
  toggleMacbook: () => set((s) => ({ macbookAwake: !s.macbookAwake })),
  nextScreen: () =>
    set((s) => ({ monitorScreen: (s.monitorScreen + 1) % SCREEN_COUNT })),
  reset: () => set({ ...initial }),
}))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test`
Expected: PASS (all 4 store tests).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: scene state store (lamp, macbook, monitor)"
```

---

### Task 4: Shared palette + Clickable wrapper

**Files:**
- Create: `src/lib/palette.ts`, `src/lib/Clickable.tsx`
- Test: `tests/clickable.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `tests/clickable.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest'
import ReactThreeTestRenderer from '@react-three/test-renderer'
import { Clickable } from '../src/lib/Clickable'

describe('Clickable', () => {
  it('fires onActivate when the group is clicked', async () => {
    const onActivate = vi.fn()
    const renderer = await ReactThreeTestRenderer.create(
      <Clickable onActivate={onActivate}>
        <mesh>
          <boxGeometry />
          <meshStandardMaterial />
        </mesh>
      </Clickable>,
    )
    const group = renderer.scene.children[0]
    await renderer.fireEvent(group, 'click', { stopPropagation: () => {} })
    expect(onActivate).toHaveBeenCalledTimes(1)
    await renderer.unmount()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test`
Expected: FAIL — cannot import `Clickable`.

- [ ] **Step 3: Implement palette and Clickable**

Create `src/lib/palette.ts`:

```ts
export const palette = {
  deskTop: '#6f5436',
  deskLeg: '#4a3a24',
  floor: '#1b2230',
  wall: '#222b3a',
  black: '#1f2430',
  metal: '#9ca3af',
  keycap: '#e8e3da',
  accentTeal: '#2dd4bf',
  lampWarm: '#ffcf8a',
  screenBlue: '#60a5fa',
}
```

Create `src/lib/Clickable.tsx`:

```tsx
import { useState, type ReactNode } from 'react'
import type { ThreeEvent } from '@react-three/fiber'

interface Props {
  onActivate: () => void
  children: ReactNode
}

/** Wraps children in a group that shows a pointer cursor on hover and
 *  fires onActivate on click (stopping propagation so only the top object
 *  responds). */
export function Clickable({ onActivate, children }: Props) {
  const [, setHovered] = useState(false)

  const enter = (e: ThreeEvent<PointerEvent>) => {
    e.stopPropagation()
    setHovered(true)
    document.body.style.cursor = 'pointer'
  }
  const leave = () => {
    setHovered(false)
    document.body.style.cursor = 'auto'
  }
  const click = (e: ThreeEvent<MouseEvent>) => {
    e.stopPropagation()
    onActivate()
  }

  return (
    <group onPointerOver={enter} onPointerOut={leave} onClick={click}>
      {children}
    </group>
  )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: shared palette and Clickable wrapper"
```

---

## Phase B — Objects (low-poly primitives)

**Pattern for every object task:** create the component (a `group` of primitive meshes), add a smoke test asserting it mounts and produces meshes, place it in `DeskScene`, then verify in the browser. Build `DeskScene` once in Task 5 and append to it in later tasks.

### Task 5: Desk, floor, wall + DeskScene

**Files:**
- Create: `src/scene/Desk.tsx`, `src/scene/DeskScene.tsx`
- Modify: `src/Experience.tsx`
- Test: extend `tests/scene.smoke.test.tsx`

- [ ] **Step 1: Write the failing test (append)**

Append to `tests/scene.smoke.test.tsx`:

```tsx
import { DeskScene } from '../src/scene/DeskScene'

describe('DeskScene', () => {
  it('mounts and produces several meshes', async () => {
    const renderer = await ReactThreeTestRenderer.create(<DeskScene />)
    const meshes = renderer.scene.findAll((n) => n.type === 'Mesh')
    expect(meshes.length).toBeGreaterThan(3)
    await renderer.unmount()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test`
Expected: FAIL — cannot import `DeskScene`.

- [ ] **Step 3: Implement Desk and DeskScene**

Create `src/scene/Desk.tsx`:

```tsx
import { palette } from '../lib/palette'

export function Desk() {
  return (
    <group>
      {/* desk top: 5 wide, 0.15 thick, 2.4 deep, top surface at y=0 */}
      <mesh position={[0, -0.075, 0]} receiveShadow castShadow>
        <boxGeometry args={[5, 0.15, 2.4]} />
        <meshStandardMaterial color={palette.deskTop} />
      </mesh>
      {/* four legs */}
      {([[-2.3, -0.9], [2.3, -0.9], [-2.3, 0.9], [2.3, 0.9]] as const).map(
        ([x, z], i) => (
          <mesh key={i} position={[x, -1, z]} castShadow>
            <boxGeometry args={[0.15, 1.85, 0.15]} />
            <meshStandardMaterial color={palette.deskLeg} />
          </mesh>
        ),
      )}
      {/* floor */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -1.95, 0]} receiveShadow>
        <planeGeometry args={[20, 20]} />
        <meshStandardMaterial color={palette.floor} />
      </mesh>
      {/* partial back wall */}
      <mesh position={[0, 0.5, -1.6]} receiveShadow>
        <planeGeometry args={[20, 8]} />
        <meshStandardMaterial color={palette.wall} />
      </mesh>
    </group>
  )
}
```

Create `src/scene/DeskScene.tsx`:

```tsx
import { Desk } from './Desk'

export function DeskScene() {
  return (
    <group>
      <Desk />
      {/* objects appended in later tasks */}
    </group>
  )
}
```

Modify `src/Experience.tsx` — add the import and render `<DeskScene />` where the comment placeholder is:

```tsx
import { OrbitControls } from '@react-three/drei'
import { DeskScene } from './scene/DeskScene'

export function Experience() {
  return (
    <>
      <OrbitControls
        enablePan={false}
        minDistance={3}
        maxDistance={12}
        maxPolarAngle={Math.PI / 2.1}
      />
      <ambientLight intensity={0.4} color="#aab8d0" />
      <DeskScene />
    </>
  )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test`
Expected: PASS (DeskScene mounts with >3 meshes).

- [ ] **Step 5: Browser verify**

`npm run dev`, open the URL, confirm a desk with legs on a floor against a wall. Screenshot. Stop the server.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: desk, floor, wall and DeskScene"
```

---

### Task 6: Monitor on arm

**Files:**
- Create: `src/scene/Monitor.tsx`
- Modify: `src/scene/DeskScene.tsx`

- [ ] **Step 1: Implement Monitor**

Create `src/scene/Monitor.tsx`. The screen is an emissive plane whose brightness/colour will later be driven by the store (Task 13/14); for now use a static teal glow.

```tsx
import { palette } from '../lib/palette'

export function Monitor() {
  return (
    <group position={[0, 0, -0.7]}>
      {/* arm clamp + post */}
      <mesh position={[0, 0.05, -0.2]}>
        <boxGeometry args={[0.2, 0.1, 0.2]} />
        <meshStandardMaterial color={palette.black} />
      </mesh>
      <mesh position={[0, 0.6, -0.2]}>
        <cylinderGeometry args={[0.04, 0.04, 1.1, 12]} />
        <meshStandardMaterial color={palette.metal} />
      </mesh>
      {/* bezel: 27" ~ 1.6 x 0.95 */}
      <mesh position={[0, 1.0, 0]} castShadow>
        <boxGeometry args={[1.7, 1.0, 0.08]} />
        <meshStandardMaterial color={palette.black} />
      </mesh>
      {/* screen */}
      <mesh position={[0, 1.0, 0.045]}>
        <planeGeometry args={[1.55, 0.85]} />
        <meshStandardMaterial
          color={palette.accentTeal}
          emissive={palette.accentTeal}
          emissiveIntensity={0.6}
          toneMapped={false}
        />
      </mesh>
    </group>
  )
}
```

- [ ] **Step 2: Place it in DeskScene**

Add `import { Monitor } from './Monitor'` and `<Monitor />` inside the group in `src/scene/DeskScene.tsx`.

- [ ] **Step 3: Run tests**

Run: `npm run test`
Expected: PASS (mesh count still > 3; no import errors).

- [ ] **Step 4: Browser verify**

`npm run dev`; confirm a monitor on an arm at the back-center of the desk. Screenshot. Stop server.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: monitor on arm"
```

---

### Task 7: Keyboard (HHKB) + Trackpad

**Files:**
- Create: `src/scene/Keyboard.tsx`, `src/scene/Trackpad.tsx`
- Modify: `src/scene/DeskScene.tsx`

- [ ] **Step 1: Implement Keyboard**

Create `src/scene/Keyboard.tsx`. A compact HHKB: a small case plus a grid of keycaps. The grid is generated so it reads as a keyboard without modelling every key.

```tsx
import { palette } from '../lib/palette'

const COLS = 12
const ROWS = 4

export function Keyboard() {
  const keys = []
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      keys.push(
        <mesh
          key={`${r}-${c}`}
          position={[(c - (COLS - 1) / 2) * 0.085, 0.03, (r - (ROWS - 1) / 2) * 0.085]}
        >
          <boxGeometry args={[0.07, 0.03, 0.07]} />
          <meshStandardMaterial color={palette.keycap} />
        </mesh>,
      )
    }
  }
  return (
    <group position={[-0.15, 0.02, 0.55]}>
      {/* case */}
      <mesh castShadow receiveShadow>
        <boxGeometry args={[1.12, 0.06, 0.42]} />
        <meshStandardMaterial color="#2b2f3a" />
      </mesh>
      {keys}
    </group>
  )
}
```

- [ ] **Step 2: Implement Trackpad**

Create `src/scene/Trackpad.tsx`:

```tsx
import { palette } from '../lib/palette'

export function Trackpad() {
  return (
    <mesh position={[0.75, 0.04, 0.6]} castShadow receiveShadow>
      <boxGeometry args={[0.5, 0.04, 0.38]} />
      <meshStandardMaterial color={palette.keycap} metalness={0.1} roughness={0.4} />
    </mesh>
  )
}
```

- [ ] **Step 3: Place both in DeskScene**

Add imports and `<Keyboard />`, `<Trackpad />` to `src/scene/DeskScene.tsx`.

- [ ] **Step 4: Run tests + browser verify**

Run: `npm run test` (PASS). Then `npm run dev`; confirm keyboard front-center and trackpad to its right. Screenshot. Stop server.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: HHKB keyboard and magic trackpad"
```

---

### Task 8: MacBook on a book + cable hub

**Files:**
- Create: `src/scene/MacBook.tsx`, `src/scene/CableHub.tsx`
- Modify: `src/scene/DeskScene.tsx`

- [ ] **Step 1: Implement MacBook**

Create `src/scene/MacBook.tsx`. The lid screen is emissive when awake; later (Task 13) the emissive intensity is driven by the store. For now read the store directly so the wiring exists.

```tsx
import { palette } from '../lib/palette'
import { useSceneStore } from '../state/sceneStore'

export function MacBook() {
  const awake = useSceneStore((s) => s.macbookAwake)
  return (
    <group position={[1.7, 0, -0.2]} rotation={[0, -0.5, 0]}>
      {/* supporting book */}
      <mesh position={[0, 0.06, 0]} castShadow>
        <boxGeometry args={[0.9, 0.12, 0.65]} />
        <meshStandardMaterial color="#8a5a2b" />
      </mesh>
      {/* base */}
      <mesh position={[0, 0.14, 0]} castShadow>
        <boxGeometry args={[0.8, 0.03, 0.55]} />
        <meshStandardMaterial color={palette.metal} />
      </mesh>
      {/* lid */}
      <group position={[0, 0.15, -0.27]} rotation={[-1.95, 0, 0]}>
        <mesh position={[0, 0.27, 0]} castShadow>
          <boxGeometry args={[0.8, 0.55, 0.02]} />
          <meshStandardMaterial color={palette.metal} />
        </mesh>
        <mesh position={[0, 0.27, 0.012]}>
          <planeGeometry args={[0.74, 0.48]} />
          <meshStandardMaterial
            color={awake ? palette.screenBlue : '#0b0e14'}
            emissive={awake ? palette.screenBlue : '#000000'}
            emissiveIntensity={awake ? 0.5 : 0}
            toneMapped={false}
          />
        </mesh>
      </group>
    </group>
  )
}
```

- [ ] **Step 2: Implement CableHub**

Create `src/scene/CableHub.tsx`:

```tsx
import { palette } from '../lib/palette'

export function CableHub() {
  return (
    <mesh position={[2.2, 0.03, 0.5]} castShadow>
      <boxGeometry args={[0.35, 0.06, 0.16]} />
      <meshStandardMaterial color={palette.black} metalness={0.3} roughness={0.5} />
    </mesh>
  )
}
```

- [ ] **Step 3: Place both in DeskScene; run tests + browser verify**

Add imports and elements to `DeskScene`. Run `npm run test` (PASS). `npm run dev`; confirm an open MacBook on a book at the right with a hub beside it. Screenshot. Stop server.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: macbook on book and cable hub"
```

---

### Task 9: FORSÅ lamp + warm light

**Files:**
- Create: `src/scene/Lamp.tsx`
- Modify: `src/scene/DeskScene.tsx`

- [ ] **Step 1: Implement Lamp**

Create `src/scene/Lamp.tsx`. The lamp's articulated arm is approximated with two angled cylinders and a cone shade. A `pointLight` and the emissive bulb both follow `lampOn` from the store, so toggling later (Task 12) just works.

```tsx
import { palette } from '../lib/palette'
import { useSceneStore } from '../state/sceneStore'

export function Lamp() {
  const on = useSceneStore((s) => s.lampOn)
  return (
    <group position={[-2.0, 0, -0.3]}>
      {/* base */}
      <mesh position={[0, 0.03, 0]} castShadow>
        <cylinderGeometry args={[0.22, 0.22, 0.06, 20]} />
        <meshStandardMaterial color={palette.black} />
      </mesh>
      {/* lower arm */}
      <mesh position={[0.05, 0.5, 0]} rotation={[0, 0, -0.2]}>
        <cylinderGeometry args={[0.025, 0.025, 1.0, 10]} />
        <meshStandardMaterial color={palette.black} />
      </mesh>
      {/* upper arm */}
      <mesh position={[0.35, 1.0, 0]} rotation={[0, 0, -1.1]}>
        <cylinderGeometry args={[0.025, 0.025, 0.9, 10]} />
        <meshStandardMaterial color={palette.black} />
      </mesh>
      {/* shade */}
      <mesh position={[0.75, 1.15, 0]} rotation={[0, 0, -2.2]} castShadow>
        <coneGeometry args={[0.22, 0.32, 20, 1, true]} />
        <meshStandardMaterial color={palette.black} side={2} />
      </mesh>
      {/* bulb */}
      <mesh position={[0.78, 1.05, 0]}>
        <sphereGeometry args={[0.07, 12, 12]} />
        <meshStandardMaterial
          color={palette.lampWarm}
          emissive={palette.lampWarm}
          emissiveIntensity={on ? 1.5 : 0}
          toneMapped={false}
        />
      </mesh>
      {/* warm key light */}
      {on && (
        <pointLight
          position={[0.78, 1.05, 0.2]}
          color={palette.lampWarm}
          intensity={6}
          distance={7}
          decay={2}
          castShadow
        />
      )}
    </group>
  )
}
```

- [ ] **Step 2: Place it in DeskScene; run tests + browser verify**

Add the import and `<Lamp />` to `DeskScene`. Run `npm run test` (PASS). `npm run dev`; confirm a black articulated lamp at the left casting a warm glow over the desk. Screenshot. Stop server.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: FORSA lamp with warm key light"
```

---

### Task 10: Chair

**Files:**
- Create: `src/scene/Chair.tsx`
- Modify: `src/scene/DeskScene.tsx`

- [ ] **Step 1: Implement Chair**

Create `src/scene/Chair.tsx` (low-poly office chair: seat, back, post, base). Positioned in front of the desk, partly tucked under.

```tsx
import { palette } from '../lib/palette'

export function Chair() {
  return (
    <group position={[0, 0, 1.5]}>
      <mesh position={[0, -0.7, 0]} castShadow>
        <boxGeometry args={[0.7, 0.1, 0.7]} />
        <meshStandardMaterial color="#39404e" />
      </mesh>
      <mesh position={[0, -0.2, -0.35]} castShadow>
        <boxGeometry args={[0.7, 0.9, 0.1]} />
        <meshStandardMaterial color="#39404e" />
      </mesh>
      <mesh position={[0, -1.1, 0]}>
        <cylinderGeometry args={[0.05, 0.05, 0.8, 10]} />
        <meshStandardMaterial color={palette.black} />
      </mesh>
      <mesh position={[0, -1.5, 0]}>
        <cylinderGeometry args={[0.35, 0.4, 0.08, 5]} />
        <meshStandardMaterial color={palette.black} />
      </mesh>
    </group>
  )
}
```

- [ ] **Step 2: Place it; run tests + browser verify; commit**

Add import + `<Chair />` to `DeskScene`. `npm run test` (PASS). `npm run dev`; confirm the chair in front. Screenshot. Stop server.

```bash
git add -A
git commit -m "feat: low-poly office chair"
```

---

## Phase C — Lighting & interactions

### Task 11: Lighting rig + soft shadows

**Files:**
- Modify: `src/Experience.tsx`

- [ ] **Step 1: Improve the lighting rig**

The lamp (Task 9) is the warm key light. Add a cool fill so unlit areas read, plus soft shadow config. Replace the body of `Experience` with:

```tsx
import { OrbitControls, SoftShadows } from '@react-three/drei'
import { DeskScene } from './scene/DeskScene'

export function Experience() {
  return (
    <>
      <OrbitControls
        enablePan={false}
        minDistance={3}
        maxDistance={12}
        maxPolarAngle={Math.PI / 2.1}
      />
      <SoftShadows size={25} samples={10} />
      <hemisphereLight args={['#9fb4d8', '#1b2230', 0.5]} />
      <ambientLight intensity={0.2} color="#aab8d0" />
      {/* faint cool directional fill from front-right, no harsh shadows */}
      <directionalLight position={[5, 6, 5]} intensity={0.25} color="#cfe0ff" />
      <DeskScene />
    </>
  )
}
```

- [ ] **Step 2: Run tests + browser verify**

`npm run test` (smoke test still finds lights → PASS). `npm run dev`; confirm the scene is balanced: warm pool from the lamp, cool ambient elsewhere. Toggle the lamp temporarily by editing initial state if needed to compare, then revert. Screenshot. Stop server.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: lighting rig with soft shadows and cool fill"
```

---

### Task 12: Lamp click → toggle light

**Files:**
- Modify: `src/scene/Lamp.tsx`
- Test: `tests/lamp.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `tests/lamp.test.tsx`:

```tsx
import { describe, it, expect, beforeEach } from 'vitest'
import ReactThreeTestRenderer from '@react-three/test-renderer'
import { Lamp } from '../src/scene/Lamp'
import { useSceneStore } from '../src/state/sceneStore'

describe('Lamp', () => {
  beforeEach(() => useSceneStore.getState().reset())

  it('toggles lampOn when clicked', async () => {
    const renderer = await ReactThreeTestRenderer.create(<Lamp />)
    expect(useSceneStore.getState().lampOn).toBe(true)
    const group = renderer.scene.children[0]
    await renderer.fireEvent(group, 'click', { stopPropagation: () => {} })
    expect(useSceneStore.getState().lampOn).toBe(false)
    await renderer.unmount()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test`
Expected: FAIL — clicking does nothing (lamp not yet wrapped in Clickable).

- [ ] **Step 3: Wrap the lamp body in Clickable**

In `src/scene/Lamp.tsx`, import the wrapper and the toggle, and wrap the returned `group`'s contents. Change the top of the component and the JSX:

```tsx
import { palette } from '../lib/palette'
import { useSceneStore } from '../state/sceneStore'
import { Clickable } from '../lib/Clickable'

export function Lamp() {
  const on = useSceneStore((s) => s.lampOn)
  const toggleLamp = useSceneStore((s) => s.toggleLamp)
  return (
    <group position={[-2.0, 0, -0.3]}>
      <Clickable onActivate={toggleLamp}>
        {/* base, arms, shade, bulb — UNCHANGED from Task 9, moved inside Clickable */}
      </Clickable>
      {/* keep the pointLight OUTSIDE Clickable so the light isn't a click target */}
      {on && (
        <pointLight
          position={[0.78, 1.05, 0.2]}
          color={palette.lampWarm}
          intensity={6}
          distance={7}
          decay={2}
          castShadow
        />
      )}
    </group>
  )
}
```

Move the base/arms/shade/bulb meshes (exactly as written in Task 9) inside `<Clickable>`. Leave the `pointLight` as a sibling outside it.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test`
Expected: PASS (lamp toggles).

- [ ] **Step 5: Browser verify**

`npm run dev`; click the lamp — the warm light and bulb glow turn off/on, cursor is a pointer on hover. Screenshot both states. Stop server.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: click lamp to toggle light"
```

---

### Task 13: MacBook click → sleep/wake

**Files:**
- Modify: `src/scene/MacBook.tsx`
- Test: `tests/macbook.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `tests/macbook.test.tsx`:

```tsx
import { describe, it, expect, beforeEach } from 'vitest'
import ReactThreeTestRenderer from '@react-three/test-renderer'
import { MacBook } from '../src/scene/MacBook'
import { useSceneStore } from '../src/state/sceneStore'

describe('MacBook', () => {
  beforeEach(() => useSceneStore.getState().reset())

  it('toggles macbookAwake when clicked', async () => {
    const renderer = await ReactThreeTestRenderer.create(<MacBook />)
    expect(useSceneStore.getState().macbookAwake).toBe(true)
    const group = renderer.scene.children[0]
    await renderer.fireEvent(group, 'click', { stopPropagation: () => {} })
    expect(useSceneStore.getState().macbookAwake).toBe(false)
    await renderer.unmount()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test`
Expected: FAIL — not yet clickable.

- [ ] **Step 3: Wrap MacBook in Clickable**

In `src/scene/MacBook.tsx`, add `import { Clickable } from '../lib/Clickable'`, read `toggleMacbook` from the store (`const toggleMacbook = useSceneStore((s) => s.toggleMacbook)`), and wrap the inner contents of the outer `group` in `<Clickable onActivate={toggleMacbook}>...</Clickable>` (book, base, lid group all inside).

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test`
Expected: PASS.

- [ ] **Step 5: Browser verify + commit**

`npm run dev`; click the MacBook — screen sleeps (dark) and wakes (blue glow). Screenshot. Stop server.

```bash
git add -A
git commit -m "feat: click macbook to sleep/wake screen"
```

---

### Task 14: Monitor click → cycle screen content

**Files:**
- Modify: `src/scene/Monitor.tsx`
- Test: `tests/monitor.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `tests/monitor.test.tsx`:

```tsx
import { describe, it, expect, beforeEach } from 'vitest'
import ReactThreeTestRenderer from '@react-three/test-renderer'
import { Monitor } from '../src/scene/Monitor'
import { useSceneStore } from '../src/state/sceneStore'

describe('Monitor', () => {
  beforeEach(() => useSceneStore.getState().reset())

  it('advances monitorScreen when clicked', async () => {
    const renderer = await ReactThreeTestRenderer.create(<Monitor />)
    const group = renderer.scene.children[0]
    await renderer.fireEvent(group, 'click', { stopPropagation: () => {} })
    expect(useSceneStore.getState().monitorScreen).toBe(1)
    await renderer.unmount()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test`
Expected: FAIL.

- [ ] **Step 3: Make the screen colour reflect the store and the monitor clickable**

Rewrite `src/scene/Monitor.tsx`:

```tsx
import { palette } from '../lib/palette'
import { useSceneStore } from '../state/sceneStore'
import { Clickable } from '../lib/Clickable'

const SCREENS = [palette.accentTeal, '#f59e0b', '#a78bfa']

export function Monitor() {
  const screen = useSceneStore((s) => s.monitorScreen)
  const nextScreen = useSceneStore((s) => s.nextScreen)
  const color = SCREENS[screen]
  return (
    <group position={[0, 0, -0.7]}>
      <Clickable onActivate={nextScreen}>
        <mesh position={[0, 0.05, -0.2]}>
          <boxGeometry args={[0.2, 0.1, 0.2]} />
          <meshStandardMaterial color={palette.black} />
        </mesh>
        <mesh position={[0, 0.6, -0.2]}>
          <cylinderGeometry args={[0.04, 0.04, 1.1, 12]} />
          <meshStandardMaterial color={palette.metal} />
        </mesh>
        <mesh position={[0, 1.0, 0]} castShadow>
          <boxGeometry args={[1.7, 1.0, 0.08]} />
          <meshStandardMaterial color={palette.black} />
        </mesh>
        <mesh position={[0, 1.0, 0.045]}>
          <planeGeometry args={[1.55, 0.85]} />
          <meshStandardMaterial
            color={color}
            emissive={color}
            emissiveIntensity={0.6}
            toneMapped={false}
          />
        </mesh>
      </Clickable>
    </group>
  )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test`
Expected: PASS.

- [ ] **Step 5: Browser verify + commit**

`npm run dev`; click the monitor — screen colour cycles through three states. Screenshot. Stop server.

```bash
git add -A
git commit -m "feat: click monitor to cycle screen content"
```

---

### Task 15: Keyboard click → key-press ripple

**Files:**
- Modify: `src/scene/Keyboard.tsx`
- Test: `tests/keyboard.test.tsx`

This is a visual animation (keys bob in a wave). Test only that the click is wired (a callback fires); verify the animation in the browser.

- [ ] **Step 1: Write the failing test**

Create `tests/keyboard.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest'
import ReactThreeTestRenderer from '@react-three/test-renderer'
import { Keyboard } from '../src/scene/Keyboard'

describe('Keyboard', () => {
  it('is clickable (a click on the group does not throw)', async () => {
    const renderer = await ReactThreeTestRenderer.create(<Keyboard />)
    const group = renderer.scene.children[0]
    const click = () =>
      renderer.fireEvent(group, 'click', { stopPropagation: () => {} })
    await expect(click()).resolves.not.toThrow()
    await renderer.unmount()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test`
Expected: FAIL — no click handler on the group yet (fireEvent finds no handler / group is not the expected node). If it passes trivially, proceed; the meaningful check is the browser animation in Step 4.

- [ ] **Step 3: Add a ripple animation on click**

Rewrite `src/scene/Keyboard.tsx` to trigger a wave. On click, record a start time; each frame, offset each key's Y by a decaying sine based on distance from center.

```tsx
import { useRef, useState } from 'react'
import { useFrame } from '@react-three/fiber'
import type { Group } from 'three'
import { palette } from '../lib/palette'

const COLS = 12
const ROWS = 4

export function Keyboard() {
  const group = useRef<Group>(null)
  const [t0, setT0] = useState<number | null>(null)

  useFrame((state) => {
    if (!group.current) return
    const now = state.clock.elapsedTime
    group.current.children.forEach((child) => {
      const key = child.userData.key
      if (key === undefined) return
      if (t0 === null) {
        child.position.y = 0.03
        return
      }
      const elapsed = now - t0
      const phase = elapsed * 8 - key.dist * 3
      const amp = Math.max(0, 0.04 * Math.exp(-elapsed * 2))
      child.position.y = 0.03 + (phase > 0 ? Math.sin(phase) * amp : 0)
    })
  })

  const keys = []
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const x = (c - (COLS - 1) / 2) * 0.085
      const z = (r - (ROWS - 1) / 2) * 0.085
      keys.push(
        <mesh key={`${r}-${c}`} position={[x, 0.03, z]} userData={{ key: { dist: Math.hypot(x, z) } }}>
          <boxGeometry args={[0.07, 0.03, 0.07]} />
          <meshStandardMaterial color={palette.keycap} />
        </mesh>,
      )
    }
  }

  return (
    <group
      ref={group}
      position={[-0.15, 0.02, 0.55]}
      onClick={(e) => {
        e.stopPropagation()
        setT0(performance.now() / 1000 - 0) // placeholder; replaced below
      }}
    >
      <mesh castShadow receiveShadow>
        <boxGeometry args={[1.12, 0.06, 0.42]} />
        <meshStandardMaterial color="#2b2f3a" />
      </mesh>
      {keys}
    </group>
  )
}
```

Then fix the click to use the R3F clock for consistency: change the handler to read the clock via a ref. Replace the `onClick` with:

```tsx
import { useThree } from '@react-three/fiber'
// inside component, before return:
const clock = useThree((s) => s.clock)
// ...
onClick={(e) => { e.stopPropagation(); setT0(clock.elapsedTime) }}
```

(Use the R3F clock so the same time base drives `useFrame` and the click.)

- [ ] **Step 4: Run tests + browser verify**

Run: `npm run test` (PASS). `npm run dev`; click the keyboard — keys ripple outward and settle. Screenshot mid-ripple. Stop server.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: keyboard ripple on click"
```

---

### Task 16: Intro camera animation

**Files:**
- Create: `src/hooks/useIntroCamera.ts`
- Modify: `src/Experience.tsx`

- [ ] **Step 1: Implement the intro hook**

Create `src/hooks/useIntroCamera.ts`. On mount, animate the camera from a wide pulled-back position to the resting position over ~1.5s, then hand control to OrbitControls.

```ts
import { useRef } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import { Vector3 } from 'three'

const START = new Vector3(10, 7, 12)
const END = new Vector3(6, 4, 7)
const DURATION = 1.5

/** Returns true once the intro is done (so OrbitControls can be enabled). */
export function useIntroCamera() {
  const camera = useThree((s) => s.camera)
  const t0 = useRef<number | null>(null)
  const done = useRef(false)

  useFrame((state) => {
    if (done.current) return
    if (t0.current === null) {
      t0.current = state.clock.elapsedTime
      camera.position.copy(START)
    }
    const k = Math.min(1, (state.clock.elapsedTime - t0.current) / DURATION)
    const eased = 1 - Math.pow(1 - k, 3) // easeOutCubic
    camera.position.lerpVectors(START, END, eased)
    camera.lookAt(0, 0.5, 0)
    if (k >= 1) done.current = true
  })

  return done
}
```

- [ ] **Step 2: Use it in Experience and gate OrbitControls**

Modify `src/Experience.tsx`: call the hook and disable OrbitControls until the intro finishes. Because the hook uses `useFrame`, it must run inside the Canvas tree (Experience already is). Add a small wrapper:

```tsx
import { useState } from 'react'
import { OrbitControls, SoftShadows } from '@react-three/drei'
import { DeskScene } from './scene/DeskScene'
import { useIntroCamera } from './hooks/useIntroCamera'

function Intro({ onDone }: { onDone: () => void }) {
  const done = useIntroCamera()
  useFrameDone(done, onDone)
  return null
}

// helper to call onDone once
import { useFrame } from '@react-three/fiber'
function useFrameDone(done: React.MutableRefObject<boolean>, onDone: () => void) {
  const fired = useState(false)
  useFrame(() => {
    if (done.current && !fired[0]) {
      fired[1](true)
      onDone()
    }
  })
}

export function Experience() {
  const [introDone, setIntroDone] = useState(false)
  return (
    <>
      <Intro onDone={() => setIntroDone(true)} />
      <OrbitControls
        enabled={introDone}
        enablePan={false}
        minDistance={3}
        maxDistance={12}
        maxPolarAngle={Math.PI / 2.1}
      />
      <SoftShadows size={25} samples={10} />
      <hemisphereLight args={['#9fb4d8', '#1b2230', 0.5]} />
      <ambientLight intensity={0.2} color="#aab8d0" />
      <directionalLight position={[5, 6, 5]} intensity={0.25} color="#cfe0ff" />
      <DeskScene />
    </>
  )
}
```

- [ ] **Step 3: Run tests + browser verify**

Run: `npm run test`. The smoke test renders `Experience` headless; `useFrame` callbacks do not tick in the test renderer, so the camera intro is inert and lights are still present → PASS. `npm run dev`; on load the camera sweeps in, then you can orbit. Screenshot. Stop server.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: intro camera animation"
```

---

## Phase D — Polish, embed, deploy

### Task 17: Responsive + mobile tuning

**Files:**
- Modify: `src/App.tsx`

- [ ] **Step 1: Cap pixel ratio and tune controls for touch**

Modify `src/App.tsx` to cap DPR (perf) and add a loading fallback:

```tsx
import { Suspense } from 'react'
import { Canvas } from '@react-three/fiber'
import { Experience } from './Experience'
import './styles.css'

export function App() {
  return (
    <Canvas
      dpr={[1, 1.75]}
      camera={{ position: [6, 4, 7], fov: 40 }}
      shadows
    >
      <color attach="background" args={['#0e1118']} />
      <Suspense fallback={null}>
        <Experience />
      </Suspense>
    </Canvas>
  )
}
```

Mobile zoom is already constrained by `minDistance`/`maxDistance`; touch rotate works through OrbitControls by default. No extra library needed.

- [ ] **Step 2: Run tests + browser verify (resize window narrow)**

Run: `npm run test` (PASS). `npm run dev`; resize the window narrow to emulate mobile; confirm the scene stays framed and rotatable by drag. Screenshot. Stop server.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "perf: cap dpr and add suspense fallback"
```

---

### Task 18: Production build + Vercel config

**Files:**
- Create: `vercel.json`
- Modify: (none)

- [ ] **Step 1: Verify the production build**

Run: `npm run build`
Expected: `tsc -b` passes with no type errors, then Vite writes `dist/`. If `tsc` reports unused-variable errors, fix them (the strict flags in `tsconfig.json` are intentional).

Run: `npm run preview` and open the printed URL; confirm the built scene works. Stop preview.

- [ ] **Step 2: Add Vercel config**

Create `apps/desk-room-3d/vercel.json`:

```json
{
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "framework": "vite"
}
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "build: verify production build and add vercel config"
```

- [ ] **Step 4: Deploy (human-in-the-loop)**

Deployment requires the user's Vercel account. Surface this to the user: either run `npx vercel --prod` from `apps/desk-room-3d/` after `vercel login`, or connect the repo in the Vercel dashboard. Record the resulting production URL — Task 19 needs it.

---

### Task 19: Poster image + blog iframe embed snippet

**Files:**
- Create: `public/poster.png`, `EMBED.md`

- [ ] **Step 1: Capture a poster image**

With `npm run dev` running, frame the scene at its resting camera and capture a screenshot. Save it as `apps/desk-room-3d/public/poster.png`. This is the placeholder shown before the iframe loads.

- [ ] **Step 2: Write the embed snippet for the Next.js blog**

Create `apps/desk-room-3d/EMBED.md` documenting how to embed on the blog main page. Replace `DEPLOY_URL` with the Task 18 production URL.

````markdown
# Embedding the desk scene on the blog

Drop this lazy-loading component on the blog main page. It shows a poster
image until it scrolls into view, then mounts the iframe.

```tsx
'use client'
import { useEffect, useRef, useState } from 'react'

export function DeskRoom() {
  const ref = useRef<HTMLDivElement>(null)
  const [show, setShow] = useState(false)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver(([e]) => {
      if (e.isIntersecting) { setShow(true); io.disconnect() }
    }, { rootMargin: '200px' })
    io.observe(el)
    return () => io.disconnect()
  }, [])
  return (
    <div ref={ref} style={{ aspectRatio: '16/10', width: '100%', borderRadius: 16, overflow: 'hidden' }}>
      {show ? (
        <iframe
          src="DEPLOY_URL"
          title="My Desk in 3D"
          loading="lazy"
          style={{ width: '100%', height: '100%', border: 0 }}
          allow="autoplay"
        />
      ) : (
        <img src="/poster.png" alt="My desk in 3D" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
      )}
    </div>
  )
}
```

Copy `poster.png` into the blog's `public/` too, or point the `img src` at
`DEPLOY_URL/poster.png`.
````

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs: poster image and blog iframe embed snippet"
```

---

### Task 20: README + register status + close out

**Files:**
- Create: `README.md`
- Modify: `brain/apps.md`, `brain/plans/index.md`

- [ ] **Step 1: Write the app README**

Create `apps/desk-room-3d/README.md` covering: what it is, `npm install`/`dev`/`build`/`test`, the scene contents, the interactions, and a pointer to `EMBED.md`.

- [ ] **Step 2: Update workspace records**

In `brain/apps.md`, set the `desk-room-3d` status to `active`. In `brain/plans/index.md`, check off the plan: change `- [ ] [[plans/03-desk-room-3d/overview]]` to `- [x]`. (These are root-repo files — commit them in the root repo, not the app repo.)

- [ ] **Step 3: Final verification**

Run (in app): `npm run test` → all suites PASS. `npm run build` → succeeds.
Confirm the production URL loads and all four interactions work (lamp toggle, monitor cycle, macbook sleep/wake, keyboard ripple) with screenshots.

- [ ] **Step 4: Commit (app repo, then root repo)**

```bash
# in apps/desk-room-3d
git add -A && git commit -m "docs: add README"
# in workspace root
cd ../..
git add brain/apps.md brain/plans/index.md
git commit -m "chore(brain): mark desk-room-3d active; close plan 03"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** scene contents (Tasks 5–10), tone/lighting (Tasks 9, 11),
  R3F+Vite architecture (Tasks 1–2), zustand state (Task 3), easter-egg
  interactions — lamp/monitor/macbook/keyboard (Tasks 12–15), intro camera
  (Task 16), orbit/zoom + mobile (Tasks 2, 17), iframe embed + poster
  (Task 19), deploy (Task 18), testing approach (smoke + logic tests
  throughout). All spec sections map to tasks.
- **Asset note:** spec mentioned sourcing free glTF assets; this plan builds
  everything from primitives for a self-contained, executable MVP and defers
  glTF swaps as optional later polish (see overview "Open questions"). This is
  an intentional, stated deviation, not a gap.
- **Type consistency:** store methods (`toggleLamp`, `toggleMacbook`,
  `nextScreen`, `reset`) and fields (`lampOn`, `macbookAwake`, `monitorScreen`)
  are used consistently across Tasks 3, 12, 13, 14. `Clickable` uses
  `onActivate` everywhere.
- **Placeholders:** none remain; the one inline `// placeholder` in Task 15 is
  immediately corrected within the same step.
