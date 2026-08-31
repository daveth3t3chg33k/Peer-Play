package tmdb

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	imageBaseW500 = "https://image.tmdb.org/t/p/w500"
	imageBaseOriginal = "https://image.tmdb.org/t/p/original"
)

// Client talks to the TMDB API v3.
type Client struct {
	apiKey     string
	baseURL    string
	httpClient *http.Client
}

// NewClient creates a new TMDB client.
func NewClient(apiKey, baseURL string) *Client {
	return &Client{
		apiKey:  apiKey,
		baseURL: strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// IsConfigured returns true if the API key is set.
func (c *Client) IsConfigured() bool {
	return c.apiKey != ""
}

// TMDBMovie is the relevant subset of the TMDB movie response.
type TMDBMovie struct {
	ID               int     `json:"id"`
	Title            string  `json:"title"`
	Overview         string  `json:"overview"`
	ReleaseDate      string  `json:"release_date"`
	VoteAverage      float64 `json:"vote_average"`
	PosterPath       string  `json:"poster_path"`
	BackdropPath     string  `json:"backdrop_path"`
	GenreIDs         []int   `json:"genre_ids"`
	RuntimeMinutes   int     `json:"runtime"`
}

// TMDBVideoResult is used to extract YouTube trailer keys.
type TMDBVideoResult struct {
	Results []TMDBVideo `json:"results"`
}

type TMDBVideo struct {
	Key  string `json:"key"`
	Type string `json:"type"`
	Site string `json:"site"`
}

// TMDBPageResponse wraps a paginated TMDB response.
type TMDBPageResponse struct {
	Page         int         `json:"page"`
	Results      []TMDBMovie `json:"results"`
	TotalPages   int         `json:"total_pages"`
	TotalResults int         `json:"total_results"`
}

// MovieToSeed is the data ready for DB insertion.
type MovieToSeed struct {
	Title             string
	Description       string
	ReleaseYear       int
	Genres            []string
	PosterURL         string
	BackdropURL       string
	DurationMinutes   int
	Rating            float64
	Category          string
	YoutubeTrailerKey string
	TMDBID            int
}

// CategoryEndpoint maps our internal categories to TMDB API endpoints + params.
var CategoryEndpoint = map[string]struct {
	Endpoint string
	Params   string
}{
	"trending":  {"/trending/movie/week", ""},
	"popular":   {"/movie/popular", ""},
	"top_rated": {"/movie/top_rated", ""},
	"action":    {"/discover/movie", "with_genres=28&sort_by=popularity.desc"},
	"comedy":    {"/discover/movie", "with_genres=35&sort_by=popularity.desc"},
	"horror":    {"/discover/movie", "with_genres=27&sort_by=popularity.desc"},
	"scifi":     {"/discover/movie", "with_genres=878&sort_by=popularity.desc"},
	"drama":     {"/discover/movie", "with_genres=18&sort_by=popularity.desc"},
	"thriller":  {"/discover/movie", "with_genres=53&sort_by=popularity.desc"},
	"animation": {"/discover/movie", "with_genres=16&sort_by=popularity.desc"},
	"romance":   {"/discover/movie", "with_genres=10749&sort_by=popularity.desc"},
	"crime":     {"/discover/movie", "with_genres=80&sort_by=popularity.desc"},
	"fantasy":   {"/discover/movie", "with_genres=14&sort_by=popularity.desc"},
	"war":       {"/discover/movie", "with_genres=10752&sort_by=popularity.desc"},
	"family":    {"/discover/movie", "with_genres=10751&sort_by=popularity.desc"},
}

// GenreIDToName maps TMDB genre IDs to human-readable names.
var GenreIDToName = map[int]string{
	28:    "Action",
	12:    "Adventure",
	16:    "Animation",
	35:    "Comedy",
	80:    "Crime",
	99:    "Documentary",
	18:    "Drama",
	10751: "Family",
	14:    "Fantasy",
	36:    "History",
	27:    "Horror",
	10402: "Music",
	9648:  "Mystery",
	10749: "Romance",
	878:   "Sci-Fi",
	10770: "TV Movie",
	53:    "Thriller",
	10752: "War",
	37:    "Western",
}

// FetchMovies fetches movies for a given category from TMDB.
// It fetches up to maxPages pages (each page has ~20 movies).
func (c *Client) FetchMovies(category string, maxPages int) ([]MovieToSeed, error) {
	cfg, ok := CategoryEndpoint[category]
	if !ok {
		return nil, fmt.Errorf("unknown category: %s", category)
	}

	var allMovies []MovieToSeed

	for page := 1; page <= maxPages; page++ {
		url := fmt.Sprintf("%s%s?api_key=%s&page=%d&language=en-US", c.baseURL, cfg.Endpoint, c.apiKey, page)
		if cfg.Params != "" {
			url += "&" + cfg.Params
		}

		resp, err := c.httpClient.Get(url)
		if err != nil {
			return nil, fmt.Errorf("TMDB request failed: %w", err)
		}

		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("failed to read TMDB response: %w", err)
		}

		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("TMDB returned status %d: %s", resp.StatusCode, string(body))
		}

		var pageResp TMDBPageResponse
		if err := json.Unmarshal(body, &pageResp); err != nil {
			return nil, fmt.Errorf("failed to parse TMDB response: %w", err)
		}

		for _, m := range pageResp.Results {
			seed := movieToSeed(m, category)
			// Skip movies without posters (unusable)
			if seed.PosterURL == "" {
				continue
			}
			// Fetch trailer key for this movie
			seed.YoutubeTrailerKey = c.fetchTrailerKey(m.ID)
			allMovies = append(allMovies, seed)
		}

		// Don't fetch more pages than available
		if page >= pageResp.TotalPages {
			break
		}
	}

	return allMovies, nil
}

// SearchMovieByName searches TMDB for a movie by title and returns its TMDB ID.
// Returns 0 if not found.
func (c *Client) SearchMovieByName(title string) int {
	url := fmt.Sprintf("%s/search/movie?api_key=%s&query=%s&language=en-US", c.baseURL, c.apiKey, title)
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return 0
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0
	}
	var pageResp TMDBPageResponse
	if err := json.NewDecoder(resp.Body).Decode(&pageResp); err != nil {
		return 0
	}
	if len(pageResp.Results) == 0 {
		return 0
	}
	return pageResp.Results[0].ID
}

// FetchTrailerKey gets the YouTube trailer key for a movie by TMDB ID.
// Exported so the handler can call it directly.
func (c *Client) FetchTrailerKey(tmdbID int) string {
	return c.fetchTrailerKey(tmdbID)
}

// fetchTrailerKey gets the YouTube trailer key for a movie.
func (c *Client) fetchTrailerKey(tmdbID int) string {
	url := fmt.Sprintf("%s/movie/%d/videos?api_key=%s&language=en-US", c.baseURL, tmdbID, c.apiKey)

	resp, err := c.httpClient.Get(url)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ""
	}

	var videoResp TMDBVideoResult
	if err := json.NewDecoder(resp.Body).Decode(&videoResp); err != nil {
		return ""
	}

	// Prefer YouTube trailers
	for _, v := range videoResp.Results {
		if v.Site == "YouTube" && v.Type == "Trailer" {
			return v.Key
		}
	}
	// Fall back to any YouTube video
	for _, v := range videoResp.Results {
		if v.Site == "YouTube" {
			return v.Key
		}
	}
	return ""
}

func movieToSeed(m TMDBMovie, category string) MovieToSeed {
	// Parse release year
	year := 0
	if len(m.ReleaseDate) >= 4 {
		fmt.Sscanf(m.ReleaseDate[:4], "%d", &year)
	}

	// Map genre IDs to names
	var genres []string
	for _, gid := range m.GenreIDs {
		if name, ok := GenreIDToName[gid]; ok {
			genres = append(genres, name)
		}
	}

	// Build poster/backdrop URLs
	posterURL := ""
	if m.PosterPath != "" {
		posterURL = imageBaseW500 + m.PosterPath
	}
	backdropURL := ""
	if m.BackdropPath != "" {
		backdropURL = imageBaseOriginal + m.BackdropPath
	}

	runtime := m.RuntimeMinutes
	if runtime == 0 {
		runtime = 120 // default estimate
	}

	return MovieToSeed{
		Title:           m.Title,
		Description:     m.Overview,
		ReleaseYear:     year,
		Genres:          genres,
		PosterURL:       posterURL,
		BackdropURL:     backdropURL,
		DurationMinutes: runtime,
		Rating:          m.VoteAverage,
		Category:        category,
		TMDBID:          m.ID,
	}
}
