package core

import (
	"errors"
	"sync"
	"time"
)

type lruCache struct {
	mu       sync.RWMutex
	capacity int
	items    map[int64]*Gallery
	order    []int64
}

func newLRUCache(capacity int) *lruCache {
	return &lruCache{
		capacity: capacity,
		items:    make(map[int64]*Gallery),
		order:    make([]int64, 0, capacity),
	}
}

func (c *lruCache) Get(id int64) (*Gallery, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	item, exists := c.items[id]
	if !exists {
		return nil, false
	}

	for i, k := range c.order {
		if k == id {
			c.order = append(c.order[:i], c.order[i+1:]...)
			break
		}
	}
	c.order = append(c.order, id)
	return item, true
}

func (c *lruCache) Put(gallery *Gallery) {
	if gallery == nil || gallery.ID == 0 {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()

	if _, exists := c.items[gallery.ID]; exists {
		for i, k := range c.order {
			if k == gallery.ID {
				c.order = append(c.order[:i], c.order[i+1:]...)
				break
			}
		}
	} else if len(c.order) >= c.capacity {
		oldest := c.order[0]
		c.order = c.order[1:]
		delete(c.items, oldest)
	}

	c.order = append(c.order, gallery.ID)
	c.items[gallery.ID] = gallery
}

// ggTable is the parsed form of gg.js: reparsing the ~40KB script per image was
// the bulk of the cost on retry storms.
type ggTable struct {
	commonKey     string
	defaultDomain int
	offsets       map[int64]int
}

type ggCache struct {
	mu          sync.Mutex
	table       *ggTable
	fetchedAt   time.Time
	attemptedAt time.Time
	ttl         time.Duration
	minRefresh  time.Duration
	inflight    chan struct{}
	lastErr     error
}

func newGgCache(ttl, minRefresh time.Duration) *ggCache {
	return &ggCache{ttl: ttl, minRefresh: minRefresh}
}

// Load returns the cached table, running at most one fetch at a time so a screen
// full of failing images cannot fan out into one gg.js request each. forceRefresh
// is ignored while the cooldown since the last attempt has not elapsed.
func (c *ggCache) Load(forceRefresh bool, fetch func() (*ggTable, error)) (*ggTable, error) {
	c.mu.Lock()

	if wait := c.inflight; wait != nil {
		c.mu.Unlock()
		<-wait
		c.mu.Lock()
		table, err := c.table, c.lastErr
		c.mu.Unlock()
		return ggResult(table, err)
	}

	stale := c.table == nil || forceRefresh || time.Since(c.fetchedAt) >= c.ttl
	cooling := !c.attemptedAt.IsZero() && time.Since(c.attemptedAt) < c.minRefresh
	if !stale || cooling {
		table, err := c.table, c.lastErr
		c.mu.Unlock()
		return ggResult(table, err)
	}

	done := make(chan struct{})
	c.inflight = done
	c.attemptedAt = time.Now()
	c.mu.Unlock()

	table, err := fetch()

	c.mu.Lock()
	c.lastErr = err
	if err == nil && table != nil {
		c.table = table
		c.fetchedAt = time.Now()
	}
	cached := c.table
	c.inflight = nil
	c.mu.Unlock()
	close(done)

	return ggResult(cached, err)
}

func ggResult(table *ggTable, err error) (*ggTable, error) {
	if table != nil {
		return table, nil
	}
	if err != nil {
		return nil, err
	}
	return nil, errors.New("gg.js unavailable")
}
