package core

import (
	"testing"
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
	hash := "a98dcd6e984ad6039c8096087074881b60d5a9146f82fdf5adfa88dcf383a9ba"
	url := buildImageUrl(hash, sampleGg)
	expected := "https://w2.gold-usergeneratedcontent.net/1789239601/2715/a98dcd6e984ad6039c8096087074881b60d5a9146f82fdf5adfa88dcf383a9ba.webp"
	if url != expected {
		t.Fatalf("expected %q, got %q", expected, url)
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
	t.Logf("Suggestions for 'fem': %+v", sugg)
	if len(sugg) == 0 {
		t.Fatalf("expected suggestions for 'fem'")
	}
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

