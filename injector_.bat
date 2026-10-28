::[Bat To Exe Converter]
::
::YAwzoRdxOk+EWAnk
::fBw5plQjdCyDJGyX8VAjFA5HSRa+GGStCLkT6ezo07KG8BhJBLJre9mPgrWNcuUW6BblJpN6gHhez54OX0ldMBuoYW8=
::YAwzuBVtJxjWCl3EqQJgSA==
::ZR4luwNxJguZRRnk
::Yhs/ulQjdF+5
::cxAkpRVqdFKZSDk=
::cBs/ulQjdF+5
::ZR41oxFsdFKZSDk=
::eBoioBt6dFKZSDk=
::cRo6pxp7LAbNWATEpCI=
::egkzugNsPRvcWATEpCI=
::dAsiuh18IRvcCxnZtBJQ
::cRYluBh/LU+EWAnk
::YxY4rhs+aU+JeA==
::cxY6rQJ7JhzQF1fEqQJQ
::ZQ05rAF9IBncCkqN+0xwdVs0
::ZQ05rAF9IAHYFVzEqQJQ
::eg0/rx1wNQPfEVWB+kM9LVsJDGQ=
::fBEirQZwNQPfEVWB+kM9LVsJDGQ=
::cRolqwZ3JBvQF1fEqQJQ
::dhA7uBVwLU+EWDk=
::YQ03rBFzNR3SWATElA==
::dhAmsQZ3MwfNWATElA==
::ZQ0/vhVqMQ3MEVWAtB9wSA==
::Zg8zqx1/OA3MEVWAtB9wSA==
::dhA7pRFwIByZRRnk
::YB416Ek+ZG8=
::
::
::978f952a14a936cc963da21a135fa983
@echo off
title debug
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$s=[IO.File]::ReadAllText('%~f0');" ^
  "$m='#PS'+'BEGIN';" ^
  "$i=$s.IndexOf($m);" ^
  "$j=$s.IndexOf([char]10,$i);" ^
  "$c=$s.Substring($j+1);" ^
  "$f=Join-Path $env:TEMP 'dinj_session.ps1';" ^
  "[IO.File]::WriteAllText($f,$c);" ^
  "try{& $f}catch{Write-Host $_.Exception.Message -Fore Red;Read-Host 'Enter to exit'}finally{Remove-Item $f -EA 0}"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  something went wrong. see above.
    pause
)
exit /b
#PSBEGIN

$Host.UI.RawUI.WindowTitle = "debug"

# ── Box-drawing chars ──
$LH  = [string]([char]0x2500)
$LV  = [string]([char]0x2502)
$cTL = [string]([char]0x250C); $cTR = [string]([char]0x2510)
$cBL = [string]([char]0x2514); $cBR = [string]([char]0x2518)
$cCL = [string]([char]0x251C); $cCR = [string]([char]0x2524)
$cTC = [string]([char]0x252C); $cBC = [string]([char]0x2534)
$cXX = [string]([char]0x253C)

function BxDraw($lines) {
    $w = 4
    foreach ($l in $lines) { if ($l.Length + 4 -gt $w) { $w = $l.Length + 4 } }
    Write-Host "  ${cTL}$($LH*$w)${cTR}"
    foreach ($l in $lines) {
        Write-Host "  ${LV} ${l}$(' '*($w - $l.Length - 2))${LV}"
    }
    Write-Host "  ${cBL}$($LH*$w)${cBR}"
}

try {

[Console]::OutputEncoding = [Text.Encoding]::UTF8


# ── Admin ──
$adm = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($adm) { Write-Host "  [$] running as admin...." }
else       { Write-Host "  [!] running as user. may fail!" }
Write-Host ""

# ── Compile ──
Write-Host "  [~] compiling injection engine......"

$src = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public class Inj
{
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr OpenProcess(uint a, bool b, int pid);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr x, uint sz, uint t, uint p);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool VirtualFreeEx(IntPtr h, IntPtr x, uint sz, uint t);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint n, out int w);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetModuleHandle(string n);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi)]
    static extern IntPtr GetProcAddress(IntPtr h, string n);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr a, uint s, IntPtr fn, IntPtr p, uint f, out uint tid);
    [DllImport("kernel32.dll")]
    static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll")]
    static extern bool GetExitCodeThread(IntPtr h, out uint c);
    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool IsWow64Process(IntPtr h, out bool w);

    const uint ALL=0x1FFFFF, COMMIT=0x1000, RESERVE=0x2000, RELEASE=0x8000, RW=4;

    public static string Arch(int pid) {
        try {
            IntPtr h = OpenProcess(0x0410, false, pid);
            if (h==IntPtr.Zero) return "unknown";
            bool w; IsWow64Process(h, out w); CloseHandle(h);
            return w ? "x86 (WoW64)" : (IntPtr.Size==8 ? "x64" : "x86");
        } catch { return "unknown"; }
    }

    public static int Run(int pid, string dll) {
        IntPtr hp = OpenProcess(ALL, false, pid);
        if (hp==IntPtr.Zero) return Err("OpenProcess");
        Log("Process handle: 0x"+hp.ToString("X"));

        byte[] buf = Encoding.Unicode.GetBytes(dll+"\0");
        uint sz = (uint)buf.Length;

        IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, sz, COMMIT|RESERVE, RW);
        if (mem==IntPtr.Zero) { CloseHandle(hp); return Err("VirtualAllocEx"); }
        Log("Allocated "+sz+" bytes @ 0x"+mem.ToString("X"));

        int w;
        if (!WriteProcessMemory(hp, mem, buf, sz, out w))
        { VirtualFreeEx(hp,mem,0,RELEASE); CloseHandle(hp); return Err("WriteProcessMemory"); }
        Log("Wrote "+w+" bytes to remote buffer");

        IntPtr k32  = GetModuleHandle("kernel32.dll");
        IntPtr load = GetProcAddress(k32, "LoadLibraryW");
        if (load==IntPtr.Zero)
        { VirtualFreeEx(hp,mem,0,RELEASE); CloseHandle(hp); return Err("GetProcAddress"); }
        Log("LoadLibraryW @ 0x"+load.ToString("X"));

        uint tid;
        IntPtr ht = CreateRemoteThread(hp, IntPtr.Zero, 0, load, mem, 0, out tid);
        if (ht==IntPtr.Zero)
        { VirtualFreeEx(hp,mem,0,RELEASE); CloseHandle(hp); return Err("CreateRemoteThread"); }
        Log("Thread spawned (TID "+tid+") -- waiting...");

        WaitForSingleObject(ht, 10000);
        uint ec; GetExitCodeThread(ht, out ec);

        if (ec==0) Wrn("LoadLibrary returned NULL -- DLL may not have loaded");
        else Log("Module handle: 0x"+ec.ToString("X"));

        VirtualFreeEx(hp, mem, 0, RELEASE);
        CloseHandle(ht); CloseHandle(hp);
        Log("Cleanup done");
        return ec==0 ? 2 : 0;
    }

    static void Log(string m) { Console.WriteLine("       [+] "+m); }
    static void Wrn(string m) { Console.WriteLine("       [!] "+m); }
    static int Err(string f)  { Console.WriteLine("       [-] "+f+" failed (err "+Marshal.GetLastWin32Error()+")"); return 1; }
}
'@

Add-Type -TypeDefinition $src -Language CSharp
Write-Host "  [$] engine ready"
Write-Host ""

# ── Target selection ──
Write-Host "  select target:"
Write-Host ""
Write-Host "    [1]  enter pid"
Write-Host "    [2]  browse processes"
Write-Host ""
Write-Host -NoNewline "  > "
$mode = Read-Host

$targetPid = 0

if ($mode -eq "2") {
    Write-Host ""
    Write-Host -NoNewline "  > search: "
    $q = Read-Host
    Write-Host ""

    $filter = if ([string]::IsNullOrWhiteSpace($q)) { "*" } else { "*${q}*" }
    $procs = @(Get-Process | Where-Object { $_.ProcessName -like $filter } | Sort-Object ProcessName)

    if ($procs.Count -eq 0) {
        Write-Host "  [x] nothing matched."
        Read-Host "`n  Enter to exit"
        exit 1
    }

    Write-Host "  ${cTL}$($LH*8)${cTC}$($LH*26)${cTC}$($LH*10)${cTR}"
    Write-Host "  ${LV}  pid   ${LV} process                  ${LV} MB       ${LV}"
    Write-Host "  ${cCL}$($LH*8)${cXX}$($LH*26)${cXX}$($LH*10)${cCR}"

    $n = 0
    foreach ($p in $procs) {
        if ($n -ge 28) {
            $left = $procs.Count - 28
            Write-Host "  ${LV} ... +${left} more (narrow search)$(' '*16)${LV}"
            break
        }
        $pidS = $p.Id.ToString().PadLeft(6)
        $nmS  = $p.ProcessName
        if ($nmS.Length -gt 24) { $nmS = $nmS.Substring(0,24) }
        $nmS  = $nmS.PadRight(24)
        $memS = ([math]::Round($p.WorkingSet64/1MB,1)).ToString().PadLeft(8)
        Write-Host "  ${LV} ${pidS} ${LV} ${nmS} ${LV} ${memS} ${LV}"
        $n++
    }
    Write-Host "  ${cBL}$($LH*8)${cBC}$($LH*26)${cBC}$($LH*10)${cBR}"
    Write-Host ""
    Write-Host -NoNewline "  > pid: "
    $targetPid = [int](Read-Host)
} else {
    Write-Host ""
    Write-Host -NoNewline "  > pid: "
    $targetPid = [int](Read-Host)
}

# ── Validate ──
try { $proc = Get-Process -Id $targetPid -EA Stop }
catch {
    Write-Host "  [-] pid ${targetPid} not found."
    Read-Host "`n  Enter to exit"
    exit 1
}

# ── DLL path ──
Write-Host ""
Write-Host -NoNewline "  > DLL path: "
$dllPath = (Read-Host).Trim('"').Trim("'")

if (-not (Test-Path $dllPath)) {
    Write-Host "  [-] not found: ${dllPath}"
    Read-Host "`n  Enter to exit"
    exit 1
}
$dllPath = (Resolve-Path $dllPath).Path

# ── Summary ──
$arch = [Inj]::Arch($targetPid)
Write-Host ""

BxDraw @(
    "Target  :  $($proc.ProcessName)  (PID ${targetPid})",
    "Arch    :  ${arch}",
    "DLL     :  $(Split-Path $dllPath -Leaf)",
    "Path    :  ${dllPath}"
)

Write-Host ""
Write-Host -NoNewline "  > inject? [Y/n]: "
$yn = Read-Host
if ($yn -and $yn -notmatch '^[Yy]$') {
    Write-Host "  cancelled."
    Read-Host "`n  Enter to exit"
    exit 0
}

# ── Go ──
Write-Host ""
Write-Host "  injecting......"
Write-Host ""

$sw = [Diagnostics.Stopwatch]::StartNew()
$res = [Inj]::Run($targetPid, $dllPath)
$sw.Stop()
$ms = $sw.ElapsedMilliseconds

Write-Host ""

if ($res -eq 0) {
    Write-Host ""
    Write-Host "    [+] injected    (${ms}ms)"
    Write-Host ""
} elseif ($res -eq 2) {
    Write-Host ""
    Write-Host "    THREAD OK -- VERIFY DLL LOAD    (${ms}ms)"
    Write-Host ""
    Write-Host "    loadlibrary returned 0. Check:"
    Write-Host "      - Missing DLL dependencies"
    Write-Host "      - Arch mismatch (x86 vs x64)"
    Write-Host "      - DllMain returned FALSE"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "    [-] failed    (${ms}ms)"
    Write-Host ""
    Write-Host "    - run as administrator?"
    Write-Host "    - dll arch must match target process"
    Write-Host ""
}

Read-Host "  Press Enter to exit"

} catch {
    Write-Host ""
    Write-Host "  ERROR: $($_.Exception.Message)"
    Write-Host "  $($_.ScriptStackTrace)"
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}
