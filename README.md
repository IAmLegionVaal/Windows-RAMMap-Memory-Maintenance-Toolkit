# Windows RAMMap Memory Maintenance Toolkit

A guarded PowerShell toolkit for Windows memory diagnostics and tested RAMMap maintenance actions, created by **Dewald Pretorius**.

## Files

- `Windows_RAMMap_Memory_Maintenance_Toolkit.ps1` — diagnostics, official RAMMap installation and memory maintenance.
- `Launch_RAMMap_Memory_Maintenance.bat` — interactive technician menu.

## Actual maintenance actions

The repository includes the real RAMMap actions from the tested source scripts:

- Empty the Windows standby memory list.
- Trim process working sets.
- Run both actions as a combined maintenance workflow.
- Download RAMMap from the Microsoft Sysinternals download endpoint when it is missing.

The cleaned version does not create a hidden scheduled task, bypass UAC or delete Windows Prefetch data.

## Usage

Diagnose only:

```powershell
.\Windows_RAMMap_Memory_Maintenance_Toolkit.ps1 -Action Diagnose
```

Preview the combined maintenance workflow:

```powershell
.\Windows_RAMMap_Memory_Maintenance_Toolkit.ps1 -Action RepairAllSafe -DryRun
```

Run the tested combined maintenance workflow:

```powershell
.\Windows_RAMMap_Memory_Maintenance_Toolkit.ps1 -Action RepairAllSafe
```

Run individual actions:

```powershell
.\Windows_RAMMap_Memory_Maintenance_Toolkit.ps1 -Action EmptyStandbyList
.\Windows_RAMMap_Memory_Maintenance_Toolkit.ps1 -Action EmptyWorkingSets
```

## Safety and validation

- Real maintenance actions require administrator rights.
- Changes require typing `REPAIR` unless `-Yes` is supplied.
- `-DryRun` previews actions.
- RAMMap is downloaded only from Microsoft Sysinternals.
- Every copied RAMMap executable must have a valid Microsoft Authenticode signature.
- Before-and-after memory snapshots and a comparison report are generated.
- Working-set trimming can temporarily make applications reload data from disk.

The original RAMMap maintenance actions were tested successfully by the author on his own Windows machines. This repository preserves those working actions while adding controls, validation and reporting. Results can vary with Windows version, available memory, application workload and endpoint security software.

## Output

Each run creates a timestamped folder on the desktop containing:

- `before.json`
- `after.json`
- `comparison.json`
- `maintenance.log`

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Completed successfully |
| 4 | Elevation required |
| 10 | User cancelled |
| 20 | Download, validation or maintenance failure |
