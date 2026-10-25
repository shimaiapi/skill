param([int]$TargetProcessId)
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class PackageProcessCheck {
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,uint id);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern int GetPackageFamilyName(IntPtr process,ref uint length,StringBuilder name);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 public static string Family(int id){var h=OpenProcess(0x1000,false,(uint)id);if(h==IntPtr.Zero)throw new Exception("OpenProcess error "+Marshal.GetLastWin32Error());try{uint len=0;int code=GetPackageFamilyName(h,ref len,null);if(code==15700)return "NO_PACKAGE";if(code!=122)throw new Exception("GetPackageFamilyName error "+code);var b=new StringBuilder((int)len);code=GetPackageFamilyName(h,ref len,b);if(code!=0)throw new Exception("GetPackageFamilyName error "+code);return b.ToString();}finally{CloseHandle(h);}}
}
'@
[PSCustomObject]@{ProcessId=$TargetProcessId;PackageFamily=[PackageProcessCheck]::Family($TargetProcessId)} | ConvertTo-Json -Compress
