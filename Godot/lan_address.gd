extends RefCounted
## Display-only address choice; sockets still listen on all IPv4 interfaces.

static func usable_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address() or address.contains(":"):
		return false
	var parts := address.split(".")
	var first := int(parts[0])
	return first > 0 and first < 224 and first != 127 and not address.begins_with("169.254.")

static func choose(addresses: PackedStringArray, routed: PackedStringArray) -> String:
	var candidates: Array[String] = []
	for address in addresses:
		if usable_ipv4(address) and not candidates.has(address):
			candidates.append(address)
	var preferred: Array[String] = []
	for address in routed:
		if candidates.has(address) and not preferred.has(address):
			preferred.append(address)
	if preferred.size() == 1:
		return preferred[0]
	if preferred.is_empty() and candidates.size() == 1:
		return candidates[0]
	# Never label an arbitrary virtual/VPN/multihomed address as the LAN choice.
	return ""

static func detect() -> String:
	return choose(IP.get_local_addresses(), default_route_addresses())

static func default_route_addresses() -> PackedStringArray:
	if OS.get_name() != "Windows":
		return PackedStringArray()
	# Read route/interface metrics, not adapter names or fixed address prefixes.
	# No packets, DNS, configuration changes, or elevation requests are made.
	var script := """
$ErrorActionPreference = 'Stop'
try {
  $ranked = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' | ForEach-Object {
    $iface = Get-NetIPInterface -AddressFamily IPv4 -InterfaceIndex $_.InterfaceIndex
    if ($iface.ConnectionState -eq 'Connected') {
      [pscustomobject]@{ Index = $_.InterfaceIndex; Score = [int]$_.RouteMetric + [int]$iface.InterfaceMetric }
    }
  } | Sort-Object Score)
  $addresses = @()
  if ($ranked.Count -gt 0) {
    $best = $ranked[0].Score
    $addresses = @($ranked | Where-Object { $_.Score -eq $best } | ForEach-Object {
      Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $_.Index -AddressState Preferred |
        Where-Object { -not $_.SkipAsSource } | Select-Object -ExpandProperty IPAddress
    } | Select-Object -Unique)
  }
  ConvertTo-Json -Compress -InputObject @($addresses)
} catch { '[]' }
"""
	var output: Array = []
	var executable := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	var result := OS.execute(executable, ["-NoProfile", "-NonInteractive", "-Command", script], output, false, false)
	if result != 0 or output.is_empty():
		return PackedStringArray()
	var parsed: Variant = JSON.parse_string(str(output[0]).strip_edges())
	var addresses := PackedStringArray()
	if parsed is Array:
		for address in parsed:
			if address is String:
				addresses.append(address)
	return addresses
