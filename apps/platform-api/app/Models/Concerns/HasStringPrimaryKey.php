<?php

namespace App\Models\Concerns;

trait HasStringPrimaryKey
{
    public function getIncrementing(): bool
    {
        return false;
    }

    public function getKeyType(): string
    {
        return 'string';
    }
}
