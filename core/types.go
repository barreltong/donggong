package core

type GalleryImage struct {
	Hash   string `json:"hash"`
	URL    string `json:"url"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
}

type Gallery struct {
	ID         int64          `json:"id"`
	Title      string         `json:"title"`
	Thumbnail  string         `json:"thumbnail"`
	Artists    []string       `json:"artists"`
	Groups     []string       `json:"groups"`
	Characters []string       `json:"characters"`
	Parodys    []string       `json:"parodys"`
	Type       string         `json:"type"`
	Language   string         `json:"language"`
	Tags       []string       `json:"tags"`
	Images     []GalleryImage `json:"images,omitempty"`
	PageCount  int            `json:"pageCount"`
	IsError    bool           `json:"isError,omitempty"`
}

type GalleryListResult struct {
	Galleries  []Gallery `json:"galleries"`
	TotalCount int       `json:"totalCount"`
}

type TagSuggestion struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
	Type  string `json:"type"`
}
