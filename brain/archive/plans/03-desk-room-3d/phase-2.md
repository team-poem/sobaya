# desk-room-3d — Phase 2: Visual Overhaul Plan

> **For agentic workers:** execute task-by-task. This is a visual-polish phase: TDD applies only to logic; visual changes are gated on "existing tests stay green + `npm run build` succeeds", with final verification done by the user in a browser.

**Goal:** Raise the scene from bare-primitive MVP to a cozy, designed look — without Blender or external glTF — via post-processing, better shading/shadows, rounded geometry, more detail, and blog-screenshot screen textures.

**Decisions (locked):** Screen content = the user's blog screen (monitor = blog main screenshot, MacBook = editor/blog). Tier 2 assets = in-code detail enhancement (no downloads). Blog image is provided by the user; until then use a committed placeholder.

**Tech added:** `@react-three/postprocessing`, `postprocessing`. drei helpers already available: `Environment`, `ContactShadows`, `RoundedBox`, `useTexture`.

**Critical constraint — keep headless tests green:** the smoke/interaction tests render `Experience` and scene components via `@react-three/test-renderer` (no real WebGL). Therefore:
- Put `EffectComposer`, `Environment`, and `ContactShadows` in **`App.tsx`** (inside `<Canvas>`, as siblings to `<Experience/>`), NOT inside `Experience` — App is not unit-tested, so these GL-heavy / asset-loading nodes won't break the test renderer.
- Screen textures must load resiliently (see Task 6) so `Monitor`/`MacBook` still mount under test-renderer.
- After every task: `npm run test` (all current tests pass) AND `npm run build` succeeds.

---

## Task 1: Add post-processing pipeline (Bloom + tone mapping)

**Files:** `package.json` (deps), `src/App.tsx`

- [ ] Install: `npm i @react-three/postprocessing postprocessing`
- [ ] In `src/App.tsx`, set ACES tone mapping on the renderer and add an `EffectComposer` with `Bloom` as a sibling to `<Experience/>` inside `<Canvas>`:

```tsx
import { Suspense } from 'react'
import { Canvas } from '@react-three/fiber'
import { ACESFilmicToneMapping } from 'three'
import { EffectComposer, Bloom } from '@react-three/postprocessing'
import { Experience } from './Experience'
import './styles.css'

export function App() {
  return (
    <Canvas
      dpr={[1, 1.75]}
      shadows
      gl={{ toneMapping: ACESFilmicToneMapping, antialias: true }}
      camera={{ position: [6, 4, 7], fov: 40 }}
    >
      <color attach="background" args={['#0e1118']} />
      <Suspense fallback={null}>
        <Experience />
        <EffectComposer>
          <Bloom mipmapBlur luminanceThreshold={1.0} intensity={0.6} />
        </EffectComposer>
      </Suspense>
    </Canvas>
  )
}
```

Note: emissive screen/bulb materials already use `toneMapped={false}` and high emissive — Bloom with `luminanceThreshold≈1.0` will make the lamp bulb and screens glow. Tune intensity to taste.

- [ ] Gate: `npm run test` green, `npm run build` succeeds. Commit: `feat: add bloom + ACES tone mapping`

## Task 2: Ambient occlusion + vignette

**Files:** `src/App.tsx`

- [ ] Add AO and a vignette to the composer. Prefer `N8AO` from `@react-three/postprocessing` if exported; else fall back to `SSAO` from the same package. Add `Vignette` too:

```tsx
import { EffectComposer, Bloom, N8AO, Vignette } from '@react-three/postprocessing'
// inside <EffectComposer>:
<N8AO aoRadius={0.5} intensity={2} distanceFalloff={1} />
<Bloom mipmapBlur luminanceThreshold={1.0} intensity={0.6} />
<Vignette eskil={false} offset={0.25} darkness={0.6} />
```

If `N8AO` is not exported by the installed version, use:
```tsx
import { SSAO } from '@react-three/postprocessing'
<SSAO samples={16} radius={0.2} intensity={20} luminanceInfluence={0.5} />
```
Note effect order matters: AO before Bloom before Vignette.

- [ ] Gate: tests green, build succeeds. Commit: `feat: add ambient occlusion and vignette`

## Task 3: Soft contact shadows + environment reflections

**Files:** `src/App.tsx` (ContactShadows, Environment), `src/Experience.tsx` (light tuning)

- [ ] In `App.tsx` (inside Canvas, sibling to Experience) add drei `ContactShadows` just above the floor and an `Environment` for subtle reflections (no visible background):

```tsx
import { ContactShadows, Environment } from '@react-three/drei'
// inside Canvas, before/after <Experience/>:
<ContactShadows position={[0, -1.94, 0]} opacity={0.5} scale={20} blur={2.5} far={4} />
<Environment preset="apartment" background={false} environmentIntensity={0.3} />
```

- [ ] In `Experience.tsx`, since Environment + ContactShadows now contribute, slightly reduce the directional/ambient to avoid a washed-out look (e.g. ambient 0.15, directional 0.2). Keep `SoftShadows`. Keep the lamp pointLight as the warm key.
- [ ] Gate: tests green (Experience light-count test still passes), build succeeds. Commit: `feat: contact shadows + environment reflections`

## Task 4: Rounded geometry pass

**Files:** scene components

- [ ] Replace hard-edged `boxGeometry` with drei `RoundedBox` on the high-visibility pieces for a designed low-poly feel. Apply to: desk top, monitor bezel, MacBook base+lid, keyboard case, trackpad, cable hub, chair seat+back. Keep keycaps as cheap boxes (48 of them — rounding all is costly; optionally round with very low segments or leave as-is).

Pattern (replace `<mesh><boxGeometry args={[w,h,d]}/><material/></mesh>` with):
```tsx
import { RoundedBox } from '@react-three/drei'
<RoundedBox args={[w, h, d]} radius={0.02} smoothness={4} castShadow receiveShadow>
  <meshStandardMaterial color={...} />
</RoundedBox>
```
Choose `radius` per object (~5–15% of the smallest dimension). Don't rounded-box the floor/wall planes or cylinders.

- [ ] Gate: smoke tests still count meshes > 3 (RoundedBox renders a Mesh) → green. Build succeeds. Commit: `feat: rounded geometry on key objects`

## Task 5: Material + detail polish

**Files:** scene components, `src/lib/palette.ts`

- [ ] Tune PBR for believability: desk wood `roughness≈0.7 metalness≈0`; monitor/MacBook/lamp black bodies `roughness≈0.4 metalness≈0.5`; trackpad/metal arm higher metalness. Add a couple of small details that read well cheaply: a thin monitor stand foot, a lamp joint sphere where arms meet, chair caster hint. Keep poly budget modest.
- [ ] Optionally enrich the palette (e.g. warmer desk, slightly desaturated wall) for the cozy reference vibe.
- [ ] Gate: tests green, build succeeds. Commit: `feat: material tuning and small detail pass`

## Task 6: Blog screen textures

**Files:** `public/screens/` (placeholders), `src/scene/Monitor.tsx`, `src/scene/MacBook.tsx`, `EMBED.md`/`README.md` note

- [ ] Create committed placeholder images at `public/screens/blog.svg` (a 16:10 mock of a blog main page — header, post cards) and `public/screens/editor.svg` (a dark code-editor mock). These stand in until the user drops a real screenshot.
- [ ] Load them as textures resiliently. Use drei `useTexture` but guard so the component still mounts under the headless test renderer (where image loading does not complete). Pattern: wrap the textured plane in its own small child component and render it inside `<Suspense fallback={<plain emissive plane>}>`; OR feature-detect and fall back to the current solid-color emissive plane when the texture isn't ready. The Monitor's existing click-to-cycle should cycle: blog texture → off/dim → (optional) a second texture.

Recommended safe pattern for the Monitor screen:
```tsx
function ScreenImage({ url }: { url: string }) {
  const tex = useTexture(url)
  return <meshBasicMaterial map={tex} toneMapped={false} />
}
// in the screen mesh:
<mesh position={[0, 1.0, 0.045]}>
  <planeGeometry args={[1.55, 0.85]} />
  <Suspense fallback={<meshStandardMaterial color={color} emissive={color} emissiveIntensity={0.6} toneMapped={false} />}>
    <ScreenImage url="/screens/blog.svg" />
  </Suspense>
</mesh>
```
(Confirm the existing Monitor cycle test still passes — the store action wiring is unchanged; only the material rendering differs. If `useTexture` breaks the test renderer even with Suspense fallback, gate the textured branch behind a prop that the test doesn't set, defaulting tests to the solid-color material.)

- [ ] MacBook lid screen: same treatment with `/screens/editor.svg`, respecting `macbookAwake` (dark when asleep).
- [ ] Add a README/EMBED note: to use a real blog screenshot, drop `public/screens/blog.png` (and `editor.png`) and update the two `url` strings.
- [ ] Gate: tests green, build succeeds. Commit: `feat: blog/editor screen textures with placeholders`

## Task 7: Verify, document, screenshots

- [ ] Final `npm run test` (all green) and `npm run build` (succeeds).
- [ ] Update `README.md`: note the post-processing stack and how to swap real screen images.
- [ ] User-side (manual, flagged to orchestrator): run `npm run dev`, confirm the new look, drop a real blog screenshot, then re-capture `public/poster.png`.
- [ ] Commit: `docs: document visual pipeline`

---

## Self-review notes
- All GL-heavy/async nodes (EffectComposer, Environment, ContactShadows, textures) are kept out of the unit-tested `Experience`/scene-logic paths, or behind Suspense fallbacks, so the existing 11 tests stay green.
- No external asset downloads; placeholders are committed SVGs.
- Effect order (AO → Bloom → Vignette) and tone mapping are set explicitly.
- Open: exact Bloom/AO/vignette intensities are taste — final values set during the user's browser verification.
