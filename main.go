package main

import (
	"archive/zip"
	"bufio"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

const shutterSoundKey = "csc_pref_camera_forced_shuttersound_key"
const platformToolsURL = "https://developer.android.com/tools/releases/platform-tools"
const platformToolsWindowsZipURL = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

var version = "dev"

type Device struct {
	Serial  string
	State   string
	Model   string
	Product string
	Device  string
	RawLine string
}

func main() {
	fmt.Printf("GalaxyCameraMuteAdb v%s\n", version)

	adbPath, err := resolveAdbPath()
	if err != nil {
		exitWithError(err)
	}

	fmt.Printf("adb 경로: %s\n\n", adbPath)

	devices, otherStates, err := listDevices(adbPath)
	if err != nil {
		exitWithError(err)
	}

	if len(devices) == 0 {
		printConnectionGuidance(otherStates)
		exitWithError(errors.New("유선으로 연결된 adb 장비를 찾지 못했습니다"))
	}

	selected, err := selectDevice(devices)
	if err != nil {
		exitWithError(err)
	}

	beforeValue, err := getShutterSoundSetting(adbPath, selected.Serial)
	if err != nil {
		exitWithError(err)
	}

	fmt.Printf("\n선택된 장비: %s\n", selected.Serial)
	fmt.Printf("보내기 전 상태: %s=%s\n", shutterSoundKey, beforeValue)

	if err := disableForcedShutterSound(adbPath, selected.Serial); err != nil {
		fmt.Println("명령 결과: 실패")
		exitWithError(err)
	}

	fmt.Println("명령 결과: 성공")

	afterValue, err := getShutterSoundSetting(adbPath, selected.Serial)
	if err != nil {
		fmt.Println("상태 확인 결과: 실패")
		exitWithError(err)
	}

	fmt.Printf("보낸 후 상태: %s=%s\n", shutterSoundKey, afterValue)

	if afterValue != "0" {
		fmt.Println("상태 확인 결과: 실패")
		exitWithError(fmt.Errorf("명령 실행 후에도 설정값이 0이 아닙니다: %s", afterValue))
	}

	fmt.Println("상태 확인 결과: 성공")

	if beforeValue == afterValue {
		fmt.Println("상태 변화: 기존 값과 동일합니다.")
	} else {
		fmt.Printf("상태 변화: %s -> %s\n", beforeValue, afterValue)
	}

	fmt.Printf("\n완료: %s 장비에 카메라 셔터음 비활성화 명령을 전송했습니다.\n", selected.Serial)
}

func resolveAdbPath() (string, error) {
	if adbPath, err := exec.LookPath("adb"); err == nil {
		return adbPath, nil
	}

	var candidates []string
	if envPath := strings.TrimSpace(os.Getenv("ADB_PATH")); envPath != "" {
		candidates = append(candidates, envPath)
	}

	localCandidates := []string{
		filepath.Join(".", "platform-tools", "adb.exe"),
		filepath.Join(".", "adb.exe"),
	}
	candidates = append(candidates, localCandidates...)

	userProfile := strings.TrimSpace(os.Getenv("USERPROFILE"))
	if userProfile != "" {
		candidates = append(candidates,
			filepath.Join(userProfile, "AppData", "Local", "Android", "Sdk", "platform-tools", "adb.exe"),
			filepath.Join(userProfile, "platform-tools", "adb.exe"),
			filepath.Join(userProfile, "Downloads", "platform-tools", "adb.exe"),
		)
	}

	for _, candidate := range candidates {
		if candidate == "" {
			continue
		}

		if _, err := os.Stat(candidate); err == nil {
			absPath, absErr := filepath.Abs(candidate)
			if absErr == nil {
				return absPath, nil
			}

			return candidate, nil
		}
	}

	fmt.Println("adb를 찾지 못했습니다. 공식 Platform Tools를 자동 다운로드합니다.")

	downloadedAdbPath, err := ensureLocalPlatformTools()
	if err != nil {
		return "", fmt.Errorf(
			"adb 자동 다운로드 실패: %w\n수동 다운로드: %s",
			err,
			platformToolsURL,
		)
	}

	return downloadedAdbPath, nil
}

func listDevices(adbPath string) ([]Device, []Device, error) {
	cmd := exec.Command(adbPath, "devices", "-l")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, nil, fmt.Errorf("adb devices 실행 실패: %w\n%s", err, strings.TrimSpace(string(output)))
	}

	lines := strings.Split(strings.ReplaceAll(string(output), "\r\n", "\n"), "\n")
	var devices []Device
	var otherStates []Device

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "List of devices attached") {
			continue
		}

		device, ok := parseDeviceLine(line)
		if !ok {
			continue
		}

		if device.State == "device" {
			devices = append(devices, device)
		} else {
			otherStates = append(otherStates, device)
		}
	}

	return devices, otherStates, nil
}

func parseDeviceLine(line string) (Device, bool) {
	fields := strings.Fields(line)
	if len(fields) < 2 {
		return Device{}, false
	}

	device := Device{
		Serial:  fields[0],
		State:   fields[1],
		RawLine: line,
	}

	for _, field := range fields[2:] {
		key, value, ok := strings.Cut(field, ":")
		if !ok {
			continue
		}

		switch key {
		case "model":
			device.Model = value
		case "product":
			device.Product = value
		case "device":
			device.Device = value
		}
	}

	return device, true
}

func selectDevice(devices []Device) (Device, error) {
	fmt.Println("연결된 장비:")
	for i, device := range devices {
		fmt.Printf("%d. %s", i+1, device.Serial)

		var details []string
		if device.Model != "" {
			details = append(details, "model="+device.Model)
		}
		if device.Product != "" {
			details = append(details, "product="+device.Product)
		}
		if device.Device != "" {
			details = append(details, "device="+device.Device)
		}

		if len(details) > 0 {
			fmt.Printf(" (%s)", strings.Join(details, ", "))
		}

		fmt.Println()
	}

	fmt.Print("\n장비 번호를 선택하세요: ")

	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return Device{}, fmt.Errorf("입력을 읽지 못했습니다: %w", err)
	}

	index, err := strconv.Atoi(strings.TrimSpace(input))
	if err != nil {
		return Device{}, errors.New("숫자로 장비 번호를 입력해야 합니다")
	}

	if index < 1 || index > len(devices) {
		return Device{}, fmt.Errorf("선택 가능한 장비 번호 범위는 1부터 %d까지입니다", len(devices))
	}

	return devices[index-1], nil
}

func disableForcedShutterSound(adbPath, serial string) error {
	fmt.Printf("실행 명령: %s -s %s shell settings put system %s 0\n", adbPath, serial, shutterSoundKey)

	cmd := exec.Command(
		adbPath,
		"-s",
		serial,
		"shell",
		"settings",
		"put",
		"system",
		shutterSoundKey,
		"0",
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("명령 실행 실패: %w\n%s", err, strings.TrimSpace(string(output)))
	}

	if trimmed := strings.TrimSpace(string(output)); trimmed != "" {
		fmt.Println(trimmed)
	}

	return nil
}

func getShutterSoundSetting(adbPath, serial string) (string, error) {
	cmd := exec.Command(
		adbPath,
		"-s",
		serial,
		"shell",
		"settings",
		"get",
		"system",
		shutterSoundKey,
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("현재 설정값 조회 실패: %w\n%s", err, strings.TrimSpace(string(output)))
	}

	value := strings.TrimSpace(string(output))
	if value == "" {
		return "(empty)", nil
	}

	return value, nil
}

func printConnectionGuidance(devices []Device) {
	fmt.Println("연결 가능한 장비를 찾지 못했습니다.")

	if len(devices) > 0 {
		fmt.Println("현재 adb 에서 보이는 장비 상태:")
		for _, device := range devices {
			fmt.Printf("- %s : %s\n", device.Serial, device.State)
		}
		fmt.Println()
	}

	fmt.Println("확인 사항:")
	fmt.Println("- 휴대폰에서 개발자 모드를 켰는지 확인하세요.")
	fmt.Println("- 개발자 옵션에서 USB 디버깅을 켰는지 확인하세요.")
	fmt.Println("- USB 연결 후 휴대폰에 표시되는 디버깅 허용 팝업을 승인하세요.")
	fmt.Println("- 충전 전용이 아니라 파일 전송 가능한 USB 케이블인지 확인하세요.")
	fmt.Println("- Samsung USB 드라이버 또는 제조사 드라이버가 필요한지 확인하세요.")
}

func ensureLocalPlatformTools() (string, error) {
	targetDir := filepath.Join(".", "platform-tools")
	targetAdb := filepath.Join(targetDir, "adb.exe")

	if _, err := os.Stat(targetAdb); err == nil {
		absPath, absErr := filepath.Abs(targetAdb)
		if absErr == nil {
			return absPath, nil
		}
		return targetAdb, nil
	}

	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		return "", fmt.Errorf("platform-tools 폴더 생성 실패: %w", err)
	}

	tempZip, err := os.CreateTemp("", "platform-tools-*.zip")
	if err != nil {
		return "", fmt.Errorf("임시 zip 파일 생성 실패: %w", err)
	}
	tempZipPath := tempZip.Name()
	defer os.Remove(tempZipPath)

	defer tempZip.Close()

	fmt.Printf("다운로드 중: %s\n", platformToolsWindowsZipURL)

	resp, err := http.Get(platformToolsWindowsZipURL)
	if err != nil {
		return "", fmt.Errorf("platform-tools 다운로드 실패: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("platform-tools 다운로드 HTTP 상태 오류: %s", resp.Status)
	}

	if _, err := io.Copy(tempZip, resp.Body); err != nil {
		return "", fmt.Errorf("zip 저장 실패: %w", err)
	}

	if err := tempZip.Close(); err != nil {
		return "", fmt.Errorf("임시 zip 닫기 실패: %w", err)
	}

	fmt.Printf("압축 해제 중: %s\n", targetDir)

	if err := unzipPlatformTools(tempZipPath, targetDir); err != nil {
		return "", err
	}

	absPath, err := filepath.Abs(targetAdb)
	if err == nil {
		return absPath, nil
	}

	return targetAdb, nil
}

func unzipPlatformTools(zipPath, targetDir string) error {
	reader, err := zip.OpenReader(zipPath)
	if err != nil {
		return fmt.Errorf("zip 열기 실패: %w", err)
	}
	defer reader.Close()

	cleanTargetDir, err := filepath.Abs(targetDir)
	if err != nil {
		return fmt.Errorf("대상 경로 확인 실패: %w", err)
	}

	for _, file := range reader.File {
		if !strings.HasPrefix(file.Name, "platform-tools/") {
			continue
		}

		relativePath := strings.TrimPrefix(file.Name, "platform-tools/")
		if relativePath == "" {
			continue
		}

		destinationPath := filepath.Join(cleanTargetDir, filepath.FromSlash(relativePath))
		cleanDestinationPath := filepath.Clean(destinationPath)

		if !strings.HasPrefix(cleanDestinationPath, cleanTargetDir+string(os.PathSeparator)) && cleanDestinationPath != cleanTargetDir {
			return fmt.Errorf("압축 해제 중 잘못된 경로 감지: %s", file.Name)
		}

		if file.FileInfo().IsDir() {
			if err := os.MkdirAll(cleanDestinationPath, 0o755); err != nil {
				return fmt.Errorf("폴더 생성 실패: %w", err)
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(cleanDestinationPath), 0o755); err != nil {
			return fmt.Errorf("상위 폴더 생성 실패: %w", err)
		}

		src, err := file.Open()
		if err != nil {
			return fmt.Errorf("zip 파일 열기 실패: %w", err)
		}

		dst, err := os.OpenFile(cleanDestinationPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
		if err != nil {
			src.Close()
			return fmt.Errorf("대상 파일 생성 실패: %w", err)
		}

		_, copyErr := io.Copy(dst, src)
		closeDstErr := dst.Close()
		closeSrcErr := src.Close()

		if copyErr != nil {
			return fmt.Errorf("파일 복사 실패: %w", copyErr)
		}
		if closeDstErr != nil {
			return fmt.Errorf("대상 파일 닫기 실패: %w", closeDstErr)
		}
		if closeSrcErr != nil {
			return fmt.Errorf("zip 파일 닫기 실패: %w", closeSrcErr)
		}
	}

	targetAdb := filepath.Join(cleanTargetDir, "adb.exe")
	if _, err := os.Stat(targetAdb); err != nil {
		return fmt.Errorf("압축 해제 후 adb.exe를 찾을 수 없습니다: %w", err)
	}

	return nil
}

func exitWithError(err error) {
	fmt.Fprintf(os.Stderr, "오류: %s\n", err)
	os.Exit(1)
}
