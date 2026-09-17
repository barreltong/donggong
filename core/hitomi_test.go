package core

import (
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestParseNozomi(t *testing.T) {
	client := newHitomiClient(newDPIEngine())
	buf := []byte{
		0x00, 0x00, 0x04, 0xD2, // 1234
		0x00, 0x3F, 0xE0, 0x6A, // 4186218
	}
	ids := client.parseNozomi(buf)
	if len(ids) != 2 {
		t.Fatalf("expected 2 ids, got %d", len(ids))
	}
	if ids[0] != 1234 || ids[1] != 4186218 {
		t.Fatalf("unexpected ids: %v", ids)
	}
}

func TestNormalizeQuery(t *testing.T) {
	q := "female:big_breasts  artist:test_name   language:korean "
	normalized := normalizeQuery(q)
	expected := "female:big_breasts artist:test_name language:korean"
	if normalized != expected {
		t.Fatalf("expected %q, got %q", expected, normalized)
	}
}

func TestBuildImageUrl(t *testing.T) {
	sampleGg := `
var o = 0;
switch (g) {
case 2715:
o = 1; break;
}
return o;
b: '1789239601/'
`
	table, err := parseGgTable(sampleGg)
	if err != nil {
		t.Fatalf("parseGgTable failed: %v", err)
	}

	hash := "a98dcd6e984ad6039c8096087074881b60d5a9146f82fdf5adfa88dcf383a9ba"
	url := buildImageUrl(hash, table)
	expected := "https://w2.gold-usergeneratedcontent.net/1789239601/2715/a98dcd6e984ad6039c8096087074881b60d5a9146f82fdf5adfa88dcf383a9ba.webp"
	if url != expected {
		t.Fatalf("expected %q, got %q", expected, url)
	}

	// A hash whose id misses every case falls back to the default domain.
	missHash := "a98dcd6e984ad6039c8096087074881b60d5a9146f82fdf5adfa88dcf383a001"
	if got := buildImageUrl(missHash, table); got != "https://w1.gold-usergeneratedcontent.net/1789239601/256/"+missHash+".webp" {
		t.Fatalf("unexpected default-domain url: %q", got)
	}
}

func TestParseGgTableRejectsGarbage(t *testing.T) {
	if _, err := parseGgTable("not a gg script"); err == nil {
		t.Fatalf("expected error for unparseable gg.js")
	}
	// A truncated fetch that still carries the key but no cases must not yield a
	// table that silently routes every image to the default domain.
	if _, err := parseGgTable("b: '1789239601/'\nvar o = 0;"); err == nil {
		t.Fatalf("expected error when case table is missing")
	}
}

func TestGgCacheCoalescesAndCoolsDown(t *testing.T) {
	cache := newGgCache(time.Minute, 50*time.Millisecond)
	table := &ggTable{commonKey: "1", defaultDomain: 1, offsets: map[int64]int{}}

	var calls atomic.Int32
	fetch := func() (*ggTable, error) {
		calls.Add(1)
		time.Sleep(20 * time.Millisecond)
		return table, nil
	}

	var wg sync.WaitGroup
	for range 32 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, err := cache.Load(true, fetch); err != nil {
				t.Errorf("Load failed: %v", err)
			}
		}()
	}
	wg.Wait()

	if got := calls.Load(); got != 1 {
		t.Fatalf("expected 32 concurrent forced loads to coalesce into 1 fetch, got %d", got)
	}

	// Still inside the cooldown: a forced refresh must reuse the cached table.
	if _, err := cache.Load(true, fetch); err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if got := calls.Load(); got != 1 {
		t.Fatalf("expected cooldown to suppress refetch, got %d fetches", got)
	}

	time.Sleep(60 * time.Millisecond)
	if _, err := cache.Load(true, fetch); err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if got := calls.Load(); got != 2 {
		t.Fatalf("expected refetch after cooldown, got %d fetches", got)
	}
}

func TestGgCacheServesStaleTableOnFetchError(t *testing.T) {
	cache := newGgCache(time.Millisecond, 0)
	table := &ggTable{commonKey: "1", defaultDomain: 1, offsets: map[int64]int{}}

	if _, err := cache.Load(false, func() (*ggTable, error) { return table, nil }); err != nil {
		t.Fatalf("seed load failed: %v", err)
	}
	time.Sleep(5 * time.Millisecond)

	got, err := cache.Load(true, func() (*ggTable, error) { return nil, errors.New("network down") })
	if err != nil {
		t.Fatalf("expected stale table to be served, got error: %v", err)
	}
	if got != table {
		t.Fatalf("expected the cached table back")
	}
}

func TestGgCacheReportsErrorWithoutCachedTable(t *testing.T) {
	cache := newGgCache(time.Minute, 0)
	if _, err := cache.Load(false, func() (*ggTable, error) { return nil, errors.New("network down") }); err == nil {
		t.Fatalf("expected error when nothing is cached")
	}
}

func TestGetListIntegration(t *testing.T) {
	Init()
	result, err := client.GetList(1, "korean")
	if err != nil {
		t.Fatalf("GetList failed: %v", err)
	}
	t.Logf("Total count: %d, Galleries len: %d", result.TotalCount, len(result.Galleries))
	if len(result.Galleries) == 0 {
		t.Fatalf("expected non-empty galleries list")
	}
	firstThumb := result.Galleries[0].Thumbnail
	t.Logf("First gallery thumbnail URL: %s", firstThumb)
	if firstThumb == "" {
		t.Fatalf("expected thumbnail URL")
	}
	thumbBytes, err := FetchBytes(firstThumb)
	if err != nil {
		t.Fatalf("FetchBytes for thumbnail failed: %v", err)
	}
	t.Logf("Fetched thumbnail bytes: %d", len(thumbBytes))
}

func TestSearchIntegration(t *testing.T) {
	Init()
	result, err := client.Search("female:sole_female", 1, "korean")
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	t.Logf("Search result count: %d, galleries: %d", result.TotalCount, len(result.Galleries))
	if result.TotalCount <= 0 || len(result.Galleries) == 0 {
		t.Fatalf("expected non-empty search results")
	}
}

func TestReaderDataIntegration(t *testing.T) {
	Init()
	// Use the first ID from index
	list, err := client.GetList(1, "korean")
	if err != nil || len(list.Galleries) == 0 {
		t.Fatalf("failed to get gallery list: %v", err)
	}
	id := list.Galleries[0].ID
	readerData, err := client.GetReaderData(id)
	if err != nil {
		t.Fatalf("GetReaderData failed: %v", err)
	}
	if len(readerData.Images) == 0 {
		t.Fatalf("expected images in reader data for %d", id)
	}
	firstImg := readerData.Images[0]
	t.Logf("First image URL: %s (%dx%d)", firstImg.URL, firstImg.Width, firstImg.Height)
	if firstImg.URL == "" || firstImg.Hash == "" {
		t.Fatalf("invalid image in reader data")
	}

	// Test FetchBytes on the image URL
	bytes, err := FetchBytes(firstImg.URL)
	if err != nil {
		t.Fatalf("FetchBytes failed for image: %v", err)
	}
	if len(bytes) == 0 {
		t.Fatalf("fetched empty image bytes")
	}
	t.Logf("Fetched image bytes: %d", len(bytes))
}


func TestTagSuggestionsIntegration(t *testing.T) {
	Init()
	sugg, err := client.GetTagSuggestions("fem")
	if err != nil {
		t.Fatalf("GetTagSuggestions failed: %v", err)
	}
	t.Logf("Suggestions for 'fem': %d items (%+v)", len(sugg), sugg)
}

func TestBridgeJsonIntegration(t *testing.T) {
	Init()
	jsonStr, err := GetListJson(1, "korean")
	if err != nil {
		t.Fatalf("GetListJson failed: %v", err)
	}
	if len(jsonStr) < 50 {
		t.Fatalf("json string too short: %s", jsonStr)
	}
}

