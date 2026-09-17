package core

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	CDNBase          = "https://ltn.gold-usergeneratedcontent.net"
	TagIndexBase     = "https://tagindex.hitomi.la"
	PageSize         = 25
	NozomiRangeBytes = PageSize * 4
)

var (
	defaultDomainRe = regexp.MustCompile(`var o = (\d)`)
	offsetDomainRe  = regexp.MustCompile(`o = (\d); break;`)
	commonKeyRe     = regexp.MustCompile(`b: '(\d+)/`)
	caseRe          = regexp.MustCompile(`case (\d+):`)
	contentRangeRe  = regexp.MustCompile(`/(\d+)$`)
	cleanTagRe      = regexp.MustCompile(`[^a-z0-9_]`)
)

type hitomiClient struct {
	dpi     *dpiEngine
	cache   *lruCache
	ggCache *ggCache
}

func newHitomiClient(dpi *dpiEngine) *hitomiClient {
	return &hitomiClient{
		dpi:     dpi,
		cache:   newLRUCache(200),
		ggCache: newGgCache(5*time.Minute, 20*time.Second),
	}
}

func (h *hitomiClient) parseNozomi(buf []byte) []int64 {
	count := len(buf) / 4
	ids := make([]int64, 0, count)
	for i := 0; i+3 < len(buf); i += 4 {
		id := int64(binary.BigEndian.Uint32(buf[i : i+4]))
		ids = append(ids, id)
	}
	return ids
}

func (h *hitomiClient) getContentLength(rawURL string) (int, error) {
	_, statusCode, headers, err := h.dpi.Fetch(rawURL, map[string]string{
		"Range": "bytes=0-3",
	})
	if err != nil {
		return 0, err
	}
	if statusCode == 206 {
		contentRange := headers.Get("content-range")
		if contentRange != "" {
			if m := contentRangeRe.FindStringSubmatch(contentRange); len(m) > 1 {
				if total, err := strconv.Atoi(m[1]); err == nil {
					return total, nil
				}
			}
		}
	}
	return 0, nil
}

func (h *hitomiClient) GetList(page int, lang string) (*GalleryListResult, error) {
	if lang == "" {
		lang = "korean"
	}
	start := (page - 1) * NozomiRangeBytes
	end := page*NozomiRangeBytes - 1

	targetURL := fmt.Sprintf("%s/index-%s.nozomi", CDNBase, lang)

	var (
		bodyBytes  []byte
		statusCode int
		totalBytes int
		fetchErr   error
		lengthErr  error
		wg         sync.WaitGroup
	)

	wg.Add(2)
	go func() {
		defer wg.Done()
		bodyBytes, statusCode, _, fetchErr = h.dpi.Fetch(targetURL, map[string]string{
			"Range": fmt.Sprintf("bytes=%d-%d", start, end),
		})
	}()

	go func() {
		defer wg.Done()
		totalBytes, lengthErr = h.getContentLength(targetURL)
	}()

	wg.Wait()

	if fetchErr != nil {
		return nil, fetchErr
	}
	if lengthErr != nil {
		totalBytes = 0
	}

	if statusCode != 200 && statusCode != 206 {
		return &GalleryListResult{Galleries: []Gallery{}, TotalCount: 0}, nil
	}

	ids := h.parseNozomi(bodyBytes)
	totalCount := totalBytes / 4
	galleries := h.fetchDetailsConcurrently(ids)

	return &GalleryListResult{
		Galleries:  galleries,
		TotalCount: totalCount,
	}, nil
}

func (h *hitomiClient) Search(query string, page int, defaultLang string) (*GalleryListResult, error) {
	normalized := normalizeQuery(query)
	terms := strings.Fields(normalized)
	if len(terms) == 0 {
		return &GalleryListResult{Galleries: []Gallery{}, TotalCount: 0}, nil
	}

	hasLang := false
	for _, t := range terms {
		if strings.HasPrefix(t, "language:") {
			hasLang = true
			break
		}
	}

	lang := defaultLang
	if hasLang || lang == "" {
		lang = "all"
	}

	type termResult struct {
		term string
		ids  map[int64]struct{}
	}

	resultsChan := make(chan termResult, len(terms))
	var wg sync.WaitGroup

	for _, t := range terms {
		wg.Add(1)
		go func(term string) {
			defer wg.Done()
			ids := h.fetchIdsForTerm(term, lang)
			resultsChan <- termResult{term: term, ids: ids}
		}(t)
	}

	wg.Wait()
	close(resultsChan)

	idSets := make([]map[int64]struct{}, 0, len(terms))
	for res := range resultsChan {
		if len(res.ids) == 0 {
			return &GalleryListResult{Galleries: []Gallery{}, TotalCount: 0}, nil
		}
		idSets = append(idSets, res.ids)
	}

	sort.Slice(idSets, func(i, j int) bool {
		return len(idSets[i]) < len(idSets[j])
	})

	common := idSets[0]
	for i := 1; i < len(idSets); i++ {
		nextSet := idSets[i]
		for id := range common {
			if _, exists := nextSet[id]; !exists {
				delete(common, id)
			}
		}
		if len(common) == 0 {
			return &GalleryListResult{Galleries: []Gallery{}, TotalCount: 0}, nil
		}
	}

	sortedIds := make([]int64, 0, len(common))
	for id := range common {
		sortedIds = append(sortedIds, id)
	}
	sort.Slice(sortedIds, func(i, j int) bool {
		return sortedIds[i] > sortedIds[j]
	})

	totalCount := len(sortedIds)
	start := (page - 1) * PageSize
	if start >= totalCount {
		return &GalleryListResult{Galleries: []Gallery{}, TotalCount: totalCount}, nil
	}

	end := start + PageSize
	if end > totalCount {
		end = totalCount
	}

	pagedIds := sortedIds[start:end]
	galleries := h.fetchDetailsConcurrently(pagedIds)

	return &GalleryListResult{
		Galleries:  galleries,
		TotalCount: totalCount,
	}, nil
}

func (h *hitomiClient) fetchIdsForTerm(term, lang string) map[int64]struct{} {
	area, tag := parseTag(term)
	result := make(map[int64]struct{})

	if area == "language" {
		u := fmt.Sprintf("%s/index-%s.nozomi", CDNBase, tag)
		body, code, _, err := h.dpi.Fetch(u, nil)
		if err == nil && code == 200 {
			for _, id := range h.parseNozomi(body) {
				result[id] = struct{}{}
			}
		}
		return result
	}

	var u string
	if area == "female" || area == "male" {
		u = fmt.Sprintf("%s/tag/%s:%s-%s.nozomi", CDNBase, area, url.PathEscape(tag), lang)
	} else {
		u = fmt.Sprintf("%s/%s/%s-%s.nozomi", CDNBase, area, url.PathEscape(tag), lang)
	}

	body, code, _, err := h.dpi.Fetch(u, nil)
	if err == nil && code == 200 {
		for _, id := range h.parseNozomi(body) {
			result[id] = struct{}{}
		}
		return result
	}

	if code == 404 && lang != "all" {
		fallbackURL := fmt.Sprintf("%s/%s/%s-all.nozomi", CDNBase, area, url.PathEscape(tag))
		body, code, _, err = h.dpi.Fetch(fallbackURL, nil)
		if err == nil && code == 200 {
			for _, id := range h.parseNozomi(body) {
				result[id] = struct{}{}
			}
		}
	}

	return result
}

func (h *hitomiClient) GetDetail(id int64) (*Gallery, error) {
	if cached, ok := h.cache.Get(id); ok {
		return cached, nil
	}

	u := fmt.Sprintf("%s/galleries/%d.js", CDNBase, id)
	body, code, _, err := h.dpi.Fetch(u, nil)
	if err != nil {
		return nil, err
	}
	if code == 404 {
		return nil, fmt.Errorf("gallery %d not found (404)", id)
	}

	gallery, err := h.parseGalleryBody(id, body)
	if err != nil {
		return nil, err
	}

	h.cache.Put(gallery)
	return gallery, nil
}

func (h *hitomiClient) parseGalleryBody(id int64, body []byte) (*Gallery, error) {
	rawText := string(body)
	rawText = strings.TrimPrefix(rawText, "var galleryinfo = ")

	var raw map[string]any
	if err := json.Unmarshal([]byte(rawText), &raw); err != nil {
		return nil, err
	}

	title, _ := raw["title"].(string)
	gType, _ := raw["type"].(string)
	language, _ := raw["language"].(string)

	files, _ := raw["files"].([]any)
	pageCount := len(files)
	if pageCount == 0 {
		if pc, ok := raw["pageCount"].(float64); ok {
			pageCount = int(pc)
		}
	}

	thumb, _ := raw["thumbnail"].(string)
	if thumb == "" && len(files) > 0 {
		if f0, ok := files[0].(map[string]any); ok {
			if hash, ok := f0["hash"].(string); ok && len(hash) >= 3 {
				suffix := string(hash[len(hash)-1])
				mid := hash[len(hash)-3 : len(hash)-1]
				thumb = fmt.Sprintf("https://tn.gold-usergeneratedcontent.net/webpbigtn/%s/%s/%s.webp", suffix, mid, hash)
			}
		}
	}

	return &Gallery{
		ID:         id,
		Title:      title,
		Thumbnail:  thumb,
		Artists:    parseTagList(raw["artists"], false),
		Groups:     parseTagList(raw["groups"], false),
		Characters: parseTagList(raw["characters"], false),
		Parodys:    parseTagList(raw["parodys"], false),
		Type:       gType,
		Language:   language,
		Tags:       parseTagList(raw["tags"], true),
		PageCount:  pageCount,
	}, nil
}

func (h *hitomiClient) GetReaderData(id int64) (*Gallery, error) {
	cached, ok := h.cache.Get(id)
	if ok && len(cached.Images) > 0 {
		return cached, nil
	}

	gallery, err := h.GetDetail(id)
	if err != nil {
		return nil, err
	}

	ggTable, err := h.getGgTable(false)
	if err != nil {
		return gallery, err
	}

	u := fmt.Sprintf("%s/galleries/%d.js", CDNBase, id)
	body, _, _, err := h.dpi.Fetch(u, nil)
	if err != nil {
		return gallery, err
	}

	rawText := strings.TrimPrefix(string(body), "var galleryinfo = ")
	var raw map[string]any
	if err := json.Unmarshal([]byte(rawText), &raw); err != nil {
		return gallery, err
	}

	files, _ := raw["files"].([]any)
	images := make([]GalleryImage, 0, len(files))
	for _, f := range files {
		fMap, ok := f.(map[string]any)
		if !ok {
			continue
		}
		hash, _ := fMap["hash"].(string)
		w, _ := fMap["width"].(float64)
		height, _ := fMap["height"].(float64)
		imgURL := buildImageUrl(hash, ggTable)
		images = append(images, GalleryImage{
			Hash:   hash,
			URL:    imgURL,
			Width:  int(w),
			Height: int(height),
		})
	}

	fullGallery := *gallery
	fullGallery.Images = images
	h.cache.Put(&fullGallery)
	return &fullGallery, nil
}

func (h *hitomiClient) ResolveImageUrl(hash string, forceRefresh bool) (string, error) {
	table, err := h.getGgTable(forceRefresh)
	if err != nil {
		return "", err
	}
	return buildImageUrl(hash, table), nil
}

func (h *hitomiClient) GetTagSuggestions(query string) ([]TagSuggestion, error) {
	if query == "" {
		return []TagSuggestion{}, nil
	}
	clean := cleanTagRe.ReplaceAllString(strings.ToLower(query), "")
	if clean == "" {
		return []TagSuggestion{}, nil
	}

	path := strings.Join(strings.Split(clean, ""), "/")
	u := fmt.Sprintf("%s/global/%s.json", TagIndexBase, path)

	body, code, _, err := h.dpi.Fetch(u, nil)
	if err != nil || code != 200 {
		return []TagSuggestion{}, nil
	}

	var rawItems [][]any
	if err := json.Unmarshal(body, &rawItems); err != nil {
		return []TagSuggestion{}, nil
	}

	limit := len(rawItems)
	if limit > 20 {
		limit = 20
	}

	suggestions := make([]TagSuggestion, 0, limit)
	for i := 0; i < limit; i++ {
		item := rawItems[i]
		if len(item) < 3 {
			continue
		}
		tag, _ := item[0].(string)
		var count int
		switch c := item[1].(type) {
		case float64:
			count = int(c)
		case string:
			count, _ = strconv.Atoi(c)
		}
		itemType, _ := item[2].(string)
		suggestions = append(suggestions, TagSuggestion{
			Tag:   tag,
			Count: count,
			Type:  itemType,
		})
	}

	return suggestions, nil
}

func (h *hitomiClient) getGgTable(forceRefresh bool) (*ggTable, error) {
	return h.ggCache.Load(forceRefresh, func() (*ggTable, error) {
		u := fmt.Sprintf("%s/gg.js", CDNBase)
		body, code, _, err := h.dpi.Fetch(u, nil)
		if err != nil {
			return nil, err
		}
		if code != 200 || len(body) == 0 {
			return nil, fmt.Errorf("failed to fetch gg.js: status %d", code)
		}
		return parseGgTable(string(body))
	})
}

func (h *hitomiClient) fetchDetailsConcurrently(ids []int64) []Gallery {
	if len(ids) == 0 {
		return []Gallery{}
	}

	results := make([]*Gallery, len(ids))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)

	for i, id := range ids {
		wg.Add(1)
		go func(idx int, targetId int64) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			g, err := h.GetDetail(targetId)
			if err == nil && g != nil && g.ID != 0 {
				results[idx] = g
			}
		}(i, id)
	}

	wg.Wait()

	galleries := make([]Gallery, 0, len(ids))
	for _, g := range results {
		if g != nil {
			galleries = append(galleries, *g)
		}
	}
	return galleries
}

func parseGgTable(gg string) (*ggTable, error) {
	commonKey := ""
	if m := commonKeyRe.FindStringSubmatch(gg); len(m) > 1 {
		commonKey = m[1]
	}
	if commonKey == "" {
		return nil, fmt.Errorf("gg.js: missing common key")
	}

	defaultDomain := 1
	if m := defaultDomainRe.FindStringSubmatch(gg); len(m) > 1 {
		if v, err := strconv.Atoi(m[1]); err == nil {
			defaultDomain = v + 1
		}
	}

	offsetDomain := 1
	if m := offsetDomainRe.FindStringSubmatch(gg); len(m) > 1 {
		if v, err := strconv.Atoi(m[1]); err == nil {
			offsetDomain = v + 1
		}
	}

	matches := caseRe.FindAllStringSubmatch(gg, -1)
	if len(matches) == 0 {
		return nil, fmt.Errorf("gg.js: no case entries")
	}
	offsets := make(map[int64]int, len(matches))
	for _, m := range matches {
		if caseVal, err := strconv.ParseInt(m[1], 10, 64); err == nil {
			offsets[caseVal] = offsetDomain
		}
	}

	return &ggTable{commonKey: commonKey, defaultDomain: defaultDomain, offsets: offsets}, nil
}

func buildImageUrl(hash string, table *ggTable) string {
	if len(hash) < 3 || table == nil {
		return ""
	}

	s := string(hash[len(hash)-1]) + string(hash[len(hash)-3:len(hash)-1])
	imageId, err := strconv.ParseInt(s, 16, 64)
	if err != nil {
		return ""
	}

	domain := table.defaultDomain
	if off, exists := table.offsets[imageId]; exists {
		domain = off
	}

	return fmt.Sprintf("https://w%d.gold-usergeneratedcontent.net/%s/%d/%s.webp", domain, table.commonKey, imageId, hash)
}

func parseTagList(raw any, isTag bool) []string {
	list, ok := raw.([]any)
	if !ok {
		return []string{}
	}
	res := make([]string, 0, len(list))
	for _, item := range list {
		switch v := item.(type) {
		case string:
			if v != "" {
				res = append(res, v)
			}
		case map[string]any:
			if isTag {
				if t, ok := v["tag"].(string); ok && t != "" {
					female := isOne(v["female"])
					male := isOne(v["male"])
					if female {
						res = append(res, "female:"+t)
					} else if male {
						res = append(res, "male:"+t)
					} else {
						res = append(res, "tag:"+t)
					}
				}
			} else {
				for _, key := range []string{"artist", "group", "character", "parody"} {
					if val, ok := v[key].(string); ok && val != "" {
						res = append(res, val)
						break
					}
				}
			}
		}
	}
	return res
}

func isOne(v any) bool {
	if v == nil {
		return false
	}
	switch val := v.(type) {
	case string:
		return val == "1"
	case float64:
		return val == 1
	case int:
		return val == 1
	default:
		return false
	}
}

func normalizeTagValue(val string) string {
	trimmed := strings.TrimSpace(val)
	return strings.Join(strings.Fields(trimmed), "_")
}

func normalizeTagLabel(label string) string {
	sep := strings.Index(label, ":")
	if sep == -1 {
		return normalizeTagValue(label)
	}
	typeStr := label[:sep]
	val := label[sep+1:]
	return typeStr + ":" + normalizeTagValue(val)
}

func normalizeQuery(q string) string {
	fields := strings.Fields(q)
	normalized := make([]string, 0, len(fields))
	for _, f := range fields {
		normalized = append(normalized, normalizeTagLabel(f))
	}
	return strings.Join(normalized, " ")
}

func parseTag(label string) (string, string) {
	sep := strings.Index(label, ":")
	if sep != -1 {
		area := label[:sep]
		val := strings.ReplaceAll(normalizeTagValue(label[sep+1:]), "_", " ")
		return area, val
	}
	return "tag", strings.ReplaceAll(normalizeTagValue(label), "_", " ")
}
