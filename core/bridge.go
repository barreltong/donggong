package core

import (
	"encoding/json"
	"fmt"
	"sync"
)

var (
	clientOnce sync.Once
	client     *hitomiClient
	dpi        *dpiEngine
)

func Init() {
	clientOnce.Do(func() {
		dpi = newDPIEngine()
		client = newHitomiClient(dpi)
	})
}

func ensureInit() {
	if client == nil {
		Init()
	}
}

func GetListJson(page int, lang string) (string, error) {
	ensureInit()
	result, err := client.GetList(page, lang)
	if err != nil {
		return "", err
	}
	bytes, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func SearchJson(query string, page int, defaultLang string) (string, error) {
	ensureInit()
	result, err := client.Search(query, page, defaultLang)
	if err != nil {
		return "", err
	}
	bytes, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func GetDetailJson(id int64) (string, error) {
	ensureInit()
	result, err := client.GetDetail(id)
	if err != nil {
		return "", err
	}
	bytes, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func GetReaderDataJson(id int64) (string, error) {
	ensureInit()
	result, err := client.GetReaderData(id)
	if err != nil {
		return "", err
	}
	bytes, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func GetTagSuggestionsJson(query string) (string, error) {
	ensureInit()
	result, err := client.GetTagSuggestions(query)
	if err != nil {
		return "", err
	}
	bytes, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func ResolveImageUrl(hash string, forceRefresh bool) (string, error) {
	ensureInit()
	return client.ResolveImageUrl(hash, forceRefresh)
}

func FetchBytes(rawURL string) ([]byte, error) {
	ensureInit()
	body, code, _, err := dpi.Fetch(rawURL, nil)
	if err != nil {
		return nil, err
	}
	if code >= 400 {
		return nil, fmt.Errorf("HTTP error %d", code)
	}
	return body, nil
}
