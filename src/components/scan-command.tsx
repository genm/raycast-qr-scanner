import { Action, ActionPanel, Detail, Icon, List, open, showToast, Toast } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { useMemo } from "react";

import { presentNativeError } from "../lib/native-error";
import {
  ClassifiedScanResult,
  classifyScanResult,
  deduplicateScanResults,
  NativeScanResult,
  ScanSource,
} from "../lib/result";

type Props = {
  scan: () => Promise<NativeScanResult[]>;
  source: ScanSource;
};

export function ScanCommand({ scan, source }: Props) {
  const { data, error, isLoading, revalidate } = usePromise(scan, [], {
    // Expected permission, cancellation, and empty-result errors have dedicated UI below.
    onError: () => undefined,
  });
  const results = useMemo(() => (data ? deduplicateScanResults(data).map(classifyScanResult) : []), [data]);

  if (error) {
    const presentation = presentNativeError(error, source);
    return (
      <Detail
        markdown={`# ${presentation.title}\n\n${presentation.message}`}
        actions={
          <ActionPanel>
            {!presentation.isCancellation && (
              <Action title="Try Again" icon={Icon.ArrowClockwise} onAction={revalidate} />
            )}
            {presentation.settingsTarget && (
              <Action
                title="Open System Settings"
                icon={Icon.Gear}
                onAction={() => open(presentation.settingsTarget as string)}
              />
            )}
          </ActionPanel>
        }
      />
    );
  }

  if (isLoading) {
    return <Detail isLoading markdown={loadingMessage(source)} />;
  }

  return (
    <List isShowingDetail searchBarPlaceholder="Filter scanned QR codes…">
      {results.map((result) => (
        <ResultItem key={result.value} result={result} />
      ))}
    </List>
  );
}

function ResultItem({ result }: { result: ClassifiedScanResult }) {
  const accessories: List.Item.Accessory[] = [];
  if (result.source === "screen" && result.displayID !== undefined) {
    accessories.push({ text: `Display ${result.displayID}` });
  }
  accessories.push({ icon: iconForKind(result.kind), tooltip: result.kind });

  return (
    <List.Item
      title={result.title}
      subtitle={result.kind === "wifi" ? result.wifi?.authentication : result.value}
      accessories={accessories}
      detail={<List.Item.Detail markdown={resultMarkdown(result)} />}
      actions={<ResultActions result={result} />}
    />
  );
}

function ResultActions({ result }: { result: ClassifiedScanResult }) {
  return (
    <ActionPanel>
      {result.openTarget && (
        <Action
          title={result.kind === "fido" ? "Request Passkey" : "Open"}
          icon={result.kind === "fido" ? Icon.Key : Icon.ArrowNe}
          onAction={() =>
            result.kind === "fido" ? requestPasskey(result.openTarget as string) : open(result.openTarget as string)
          }
        />
      )}
      {result.kind !== "fido" && <Action.CopyToClipboard title="Copy QR Content" content={result.value} />}
      {result.wifi?.password && <Action.CopyToClipboard title="Copy Wi-Fi Password" content={result.wifi.password} />}
    </ActionPanel>
  );
}

function iconForKind(kind: ClassifiedScanResult["kind"]): Icon {
  if (kind === "url") return Icon.Link;
  if (kind === "email") return Icon.Envelope;
  if (kind === "phone") return Icon.Phone;
  if (kind === "wifi") return Icon.Wifi;
  if (kind === "fido") return Icon.Key;
  return Icon.Text;
}

function wifiMarkdown(result: ClassifiedScanResult): string {
  const wifi = result.wifi;
  if (!wifi) return "";
  const lines = [
    "# Wi-Fi Network",
    "",
    `**SSID:** ${escapeMarkdown(wifi.ssid ?? "Not specified")}`,
    `**Security:** ${escapeMarkdown(wifi.authentication ?? "Not specified")}`,
    `**Password:** ${escapeMarkdown(wifi.password ?? "Not specified")}`,
    `**Hidden:** ${wifi.hidden ? "Yes" : "No"}`,
    "",
    "Use the action panel to copy the full QR content or password.",
  ];
  return lines.join("\n\n");
}

function resultMarkdown(result: ClassifiedScanResult): string {
  if (result.wifi) return wifiMarkdown(result);
  if (result.kind === "fido") {
    return [
      "# FIDO Authentication",
      "This is a FIDO hybrid authentication request. Complete it with a compatible nearby passkey device.",
      "The URI can contain one-time authentication material. Share it only with the intended authenticator.",
      "Use the Request Passkey action to hand this request to a registered FIDO app.",
    ].join("\n\n");
  }
  return `# QR Code Content\n\n${escapeMarkdown(result.value)}`;
}

async function requestPasskey(uri: string): Promise<void> {
  try {
    await open(uri);
  } catch {
    await showToast({
      style: Toast.Style.Failure,
      title: "Unable to request passkey",
      message: "No app registered for FIDO requests. Use a compatible passkey device to scan the original QR code.",
    });
  }
}

function escapeMarkdown(value: string): string {
  return value.replace(/[\\`*_{}[\]()#+.!|>-]/g, "\\$&");
}

function loadingMessage(source: ScanSource): string {
  if (source === "camera") return "Opening the camera…";
  if (source === "screen") return "Scanning visible screens…";
  return "Scanning the clipboard image…";
}
