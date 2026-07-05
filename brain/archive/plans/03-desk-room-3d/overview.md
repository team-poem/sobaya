# 03 · desk-room-3d — Design Spec

Status: **shipped** (2026-07-05 audit: phase-1/phase-2 plans exist and app is built — `apps/desk-room-3d` carries feature commits through lighting/desk-arm polish; archived)
Date: 2026-06-16
App: `apps/desk-room-3d/` (new, own git repo)

## Goal

An interactive 3D desk scene for the user's blog main page. A signature
decorative hero: the visitor orbits/zooms around a low-poly desk setup, and
clicking objects triggers cute easter-egg animations/sounds. **No navigation
links** — this is ambience, not a menu. Inspired by
`SoYoung210/my-room-in-3d` (itself based on Bruno Simon's Three.js Journey
"My Room in 3D"), but built without Blender.

## Why this shape (decisions locked in brainstorming)

- **Asset-assembly, not Blender.** User cannot model in Blender. The authentic
  baked-texture pipeline is therefore out. Instead: assemble free low-poly
  glTF assets + self-made R3F primitives, lit in real time. Trades the baked
  photorealistic look for a cozy low-poly look that is fully personalizable and
  git-managed.
- **react-three-fiber, not vanilla Three.js.** The blog is Next.js/React, so an
  R3F scene component can later be extracted and embedded natively. Vite for
  dev/build.
- **Click = easter eggs only.** User explicitly declined navigation/external
  links and info-card popups. Keeps the architecture light.
- **Desk-focused scene** (like the reference), not a full bedroom.
- **No hobby props.** Minimal desk gear only.
- **Embed via iframe.** Deploy standalone, drop a lazy-loaded `<iframe>` on the
  blog main page. Decoupled, one-line embed, protects main-page performance.
  Native R3F-component embed remains a future option.

## Scene contents (from the user's real setup)

Top-down layout confirmed with the user:

- **Center-back:** 27" black monitor on a monitor arm (arm clamped to desk).
- **Front-center:** Happy Hacking Keyboard (cute/colorful) + Magic Trackpad to
  its right.
- **Right:** MacBook (open, powered on) propped on a book; a cable hub
  connected to it.
- **Left:** IKEA FORSÅ-style black work lamp, **switched on** — its warm glow
  is the scene's key light.
- Chair (hinted), partial wall + floor backdrop.

Most generic items (desk, monitor, trackpad, chair, book, hub) come from free
CC-licensed low-poly glTF packs (Poly Pizza / Kenney / Quaternius). Distinctive
items with no good asset (HHKB, FORSÅ lamp) are built from simple R3F
primitive combinations.

## Tone / lighting

Minimal desk, slightly moody, **warm lamp accent**. Real-time lighting (no
bake):

- Low cool-toned ambient/hemisphere fill.
- Warm point light at the FORSÅ lamp head + emissive "bulb" + soft glow.
- Faint emissive on the monitor and MacBook screens.

The lamp light is both mood and the most satisfying interaction (toggle).

## Architecture

```
App
└─ Experience        Canvas + camera + OrbitControls + lighting + intro anim
   └─ DeskScene      positions all objects in the layout
      ├─ Desk
      ├─ Monitor     (on arm) — click: screen content cycle / blink
      ├─ Keyboard    (HHKB)   — click: key ripple + optional keystroke sound
      ├─ Trackpad
      ├─ MacBook     (on book)— click: screen sleep ↔ wake
      ├─ CableHub
      ├─ Lamp        (FORSÅ)  — click: light on/off (glow + point light)
      └─ Chair
```

Each object is an independent component owning its own click/animation/hover
state, so it can be understood and tested in isolation. Shared scene state
(e.g. lamp on/off, which screen is showing) lives in a small store/context at
the `Experience` level; objects read/write through a defined interface.

## Interactions

- **Common:** OrbitControls (rotate + zoom, angle/zoom limits to keep the
  composition framed); intro camera move after load; hover cursor affordance on
  clickable objects.
- **Lamp click:** toggle light (point light + glow + emissive together).
- **Monitor click:** cycle/blink screen content (image loop or video texture).
- **MacBook click:** screen sleep ↔ wake.
- **Keyboard click:** key-press ripple, optional typing sound.
- **Sound:** standard scope ships 1–2 light SFX only.

## Blog embed

- Deploy standalone to **Vercel**.
- Blog main page embeds a **lazy-loaded `<iframe>`**: a static poster image
  shows until the iframe scrolls into the viewport, then the live scene loads.
  Protects initial main-page performance.
- Future: extract the R3F scene as a component for native embedding.

## Performance / quality

- Mobile: rotate only (zoom limited), capped pixel ratio.
- glTF assets draco-compressed; lazy/suspense loading with a loader.
- Target 60fps on desktop.

## Testing / verification

- Component render smoke tests (each object mounts without error).
- Logic unit tests (lamp toggle state, screen-cycle state machine).
- Real-browser visual verification: screenshot the scene, click each
  interactive object, confirm the animation/state change actually happens
  (evidence before claiming done).

## Out of scope

- Blender modeling / baked textures.
- Navigation, external links, info-card popups.
- Full-room furniture (bed, window wall), hobby props.
- Native (non-iframe) blog integration — kept as a future path, not built now.

## Open questions for planning

- Exact free-asset sources per object + license capture.
- Monitor/MacBook screen content (still images vs short looping video).
- Whether the static poster image is a rendered screenshot or a designed image.
